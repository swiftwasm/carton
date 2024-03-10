// Copyright 2020 Carton contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArgumentParser
import CartonHelpers
import CartonKit
import Foundation
import WasmTransformer

private let dependency = Entrypoint(
  fileName: "bundle.js",
  sha256: bundleEntrypointSHA256
)

enum WasmOptimizations: String, CaseIterable, ExpressibleByArgument {
  case size, none
}

struct Bundle: AsyncParsableCommand {
  @Argument(
    help: ArgumentHelp(
      "Internal: Path to the main WebAssembly file built by the SwiftPM Plugin process.",
      visibility: .private
    )
  )
  var mainWasmPath: String

  @Option(
    name: .long,
    help: ArgumentHelp(
      "Internal: Path to resources directory built by the SwiftPM Plugin process.",
      visibility: .private
    )
  )
  var resources: [String] = []

  @Option(
    help: "Specify a path to a custom `index.html` file to be used for your app.",
    completion: .file(extensions: [".html"])
  )
  var customIndexPage: String?

  @Flag(help: "Emit names and DWARF sections in the .wasm file.")
  var debugInfo: Bool = false

  @Option(
    name: .long,
    help: """
      Which optimizations to apply to the .wasm binary output.
      Available values: \(
      WasmOptimizations.allCases.map(\.rawValue).joined(separator: ", ")
      )
      """
  )
  var wasmOptimizations: WasmOptimizations = .size

  @Flag(inversion: .prefixedNo, help: "Use a content hash for the output file names.")
  var contentHash: Bool = true

  @Option
  var output: String

  static let configuration = CommandConfiguration(
    abstract: "Produces an optimized app bundle for distribution."
  )

  func run() async throws {
    let terminal = InteractiveWriter.stderr

    try dependency.check(on: localFileSystem, terminal)

    var mainWasmPath = try AbsolutePath(
      validating: mainWasmPath, relativeTo: localFileSystem.currentWorkingDirectory!)
    let buildDirectory = mainWasmPath.parentDirectory
    try terminal.logLookup(
      "Right after building the main binary size is ",
      localFileSystem.humanReadableFileSize(mainWasmPath),
      newline: true
    )

    let bundleDirectory = try AbsolutePath(
      validating: output, relativeTo: localFileSystem.currentWorkingDirectory!)
    try localFileSystem.removeFileTree(bundleDirectory)
    try localFileSystem.createDirectory(bundleDirectory, recursive: false)

    let wasmOutputFilePath = try AbsolutePath(validating: "main.wasm", relativeTo: bundleDirectory)

    if !debugInfo {
      try strip(mainWasmPath, output: wasmOutputFilePath)
      mainWasmPath = wasmOutputFilePath
      try terminal.logLookup(
        "After stripping debug info the main binary size is ",
        localFileSystem.humanReadableFileSize(mainWasmPath),
        newline: true
      )
    }

    if wasmOptimizations == .size {
      do {
        try await optimize(mainWasmPath, outputPath: wasmOutputFilePath, terminal: terminal)
      } catch {
        terminal.write(
          """
          Warning: wasm-opt failed to optimize the binary, falling back to the original binary.
          If you don't have wasm-opt installed, you can install wasm-opt by running `brew install binaryen`, `apt-get install binaryen` or `npm install -g binaryen`

          """,
          inColor: .yellow)
        if mainWasmPath != wasmOutputFilePath {
          try localFileSystem.move(from: mainWasmPath, to: wasmOutputFilePath)
        }
      }
    } else {
      if mainWasmPath != wasmOutputFilePath {
        try localFileSystem.move(from: mainWasmPath, to: wasmOutputFilePath)
      }
    }

    try copyToBundle(
      terminal: terminal,
      wasmOutputFilePath: wasmOutputFilePath,
      buildDirectory: buildDirectory,
      bundleDirectory: bundleDirectory,
      resourcesPaths: resources
    )

    terminal.write("Bundle generation finished successfully\n", inColor: .green, bold: true)
  }

  func optimize(_ inputPath: AbsolutePath, outputPath: AbsolutePath, terminal: InteractiveWriter)
    async throws
  {
    var wasmOptArgs = [
      "wasm-opt", "-Os", "--enable-bulk-memory", inputPath.pathString, "-o", outputPath.pathString,
    ]
    if debugInfo {
      wasmOptArgs.append("--debuginfo")
    }
    try await Process.run(wasmOptArgs, terminal)
    try terminal.logLookup(
      "After stripping debug info the main binary size is ",
      localFileSystem.humanReadableFileSize(outputPath),
      newline: true
    )
  }

  func strip(_ wasmPath: AbsolutePath, output: AbsolutePath) throws {
    let binary = try localFileSystem.readFileContents(wasmPath)
    let strippedBinary = try stripCustomSections(binary.contents)
    try localFileSystem.writeFileContents(output, bytes: .init(strippedBinary))
  }

  func copyToBundle(
    terminal: InteractiveWriter,
    wasmOutputFilePath: AbsolutePath,
    buildDirectory: AbsolutePath,
    bundleDirectory: AbsolutePath,
    resourcesPaths: [String]
  ) throws {
    // Rename the final binary to use a part of its hash to bust browsers and CDN caches.
    let wasmFileHash = try localFileSystem.readFileContents(wasmOutputFilePath).hexChecksum
    let mainModuleName = contentHash ? "\(wasmFileHash).wasm" : URL(fileURLWithPath: mainWasmPath).lastPathComponent
    let mainModulePath = try AbsolutePath(validating: mainModuleName, relativeTo: bundleDirectory)
    try localFileSystem.move(from: wasmOutputFilePath, to: mainModulePath)

    // Copy the bundle entrypoint, point to the binary, and give it a cachebuster name.
    let (_, _, entrypointPath) = try dependency.paths(on: localFileSystem)
    let entrypoint = try ByteString(
      encodingAsUTF8: localFileSystem.readFileContents(entrypointPath)
        .description
        .replacingOccurrences(
          of: "REPLACE_THIS_WITH_THE_MAIN_WEBASSEMBLY_MODULE",
          with: mainModuleName
        )
    )
    let entrypointName = contentHash ? "\(entrypoint.hexChecksum).js" : "index.js"
    try localFileSystem.writeFileContents(
      AbsolutePath(validating: entrypointName, relativeTo: bundleDirectory),
      bytes: entrypoint
    )

    try localFileSystem.writeFileContents(
      AbsolutePath(validating: "index.html", relativeTo: bundleDirectory),
      bytes: ByteString(
        encodingAsUTF8: HTML.indexPage(
          customContent: HTML.readCustomIndexPage(at: customIndexPage, on: localFileSystem),
          entrypointName: entrypointName
        ))
    )

    for directoryName in try localFileSystem.resourcesDirectoryNames(relativeTo: buildDirectory) {
      let resourcesPath = buildDirectory.appending(component: directoryName)
      let targetDirectory = bundleDirectory.appending(component: directoryName)

      guard localFileSystem.exists(resourcesPath, followSymlink: true) else { continue }
      terminal.logLookup("Copying resources to ", targetDirectory)
      try localFileSystem.copy(from: resourcesPath, to: targetDirectory)
    }

    for resourcesPath in resourcesPaths {
      let resourcesPath = try AbsolutePath(
        validating: resourcesPath, relativeTo: localFileSystem.currentWorkingDirectory!)
      for file in try localFileSystem.traverseRecursively(resourcesPath) {
        let targetPath = bundleDirectory.appending(component: file.basename)

        guard localFileSystem.exists(resourcesPath, followSymlink: true),
          !localFileSystem.exists(targetPath, followSymlink: true)
        else { continue }

        terminal.logLookup("Copying this resource to the root bundle directory ", file)
        try localFileSystem.copy(from: file, to: targetPath)
      }
    }
  }
}

extension ByteString {
  fileprivate var hexChecksum: String {
    String(SHA256().hash(self).hexadecimalRepresentation.prefix(16))
  }
}

extension FileSystem {
  fileprivate func humanReadableFileSize(_ path: AbsolutePath) throws -> String {
    // FIXME: should use `UnitInformationStorage`, but it's unavailable in open-source Foundation
    let attrs = try FileManager.default.attributesOfItem(atPath: path.pathString)
    return String(format: "%.2f MB", Double(attrs[.size] as! UInt64) / 1024 / 1024)
  }
}
