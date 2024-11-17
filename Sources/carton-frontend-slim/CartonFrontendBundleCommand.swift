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
import CartonCore
import CartonHelpers
import Foundation
import WasmTransformer

enum WasmOptimizations: String, CaseIterable, ExpressibleByArgument {
  case size, none
}

struct CartonFrontendBundleCommand: AsyncParsableCommand {
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

  @Option(
    name: .customLong("Xwasm-opt", withSingleDash: true),
    help: "Extra flags to pass to wasm-opt when optimizing the .wasm binary."
  )
  var extraWasmOptFlags: [String] = []

  @Flag(inversion: .prefixedNo, help: "Use a content hash for the output file names.")
  var contentHash: Bool = true

  @Option
  var output: String

  static let configuration = CommandConfiguration(
    commandName: "bundle",
    abstract: "Produces an optimized app bundle for distribution."
  )

  func run() async throws {
    let terminal = InteractiveWriter.stderr

    var mainWasmPath = try AbsolutePath(
      validating: mainWasmPath, relativeTo: localFileSystem.currentWorkingDirectory!)
    let mainModuleBaseName = mainWasmPath.basenameWithoutExt
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

    let bundle = BundleLayout(
      mainModuleBaseName: mainModuleBaseName,
      wasmSourcePath: wasmOutputFilePath,
      buildDirectory: buildDirectory,
      bundleDirectory: bundleDirectory,
      topLevelResourcePaths: resources
    )
    try bundle.copyAppEntrypoint(
      customIndexPage: customIndexPage, contentHash: contentHash, terminal: terminal)

    terminal.write(
      "Bundle successfully generated at \(bundleDirectory)\n", inColor: .green, bold: true)
  }

  func optimize(_ inputPath: AbsolutePath, outputPath: AbsolutePath, terminal: InteractiveWriter)
    async throws
  {
    var wasmOptArgs = [
      "wasm-opt", "-Os", "--enable-bulk-memory", "--enable-sign-ext",
      inputPath.pathString, "-o", outputPath.pathString,
    ]
    if debugInfo {
      wasmOptArgs.append("--debuginfo")
    }
    wasmOptArgs.append(contentsOf: extraWasmOptFlags)
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
}

extension FileSystem {
  fileprivate func humanReadableFileSize(_ path: AbsolutePath) throws -> String {
    // FIXME: should use `UnitInformationStorage`, but it's unavailable in open-source Foundation
    let attrs = try FileManager.default.attributesOfItem(atPath: path.pathString)
    return String(format: "%.2f MB", Double(attrs[.size] as! UInt64) / 1024 / 1024)
  }
}
