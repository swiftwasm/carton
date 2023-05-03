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
import Crypto
import PackageModel
import SwiftToolchain
import TSCBasic
import WasmTransformer

private let dependency = Entrypoint(
  fileName: "bundle.js",
  sha256: bundleEntrypointSHA256
)

enum WasmOptimizations: String, CaseIterable, ExpressibleByArgument {
  case size, none
}

struct Bundle: AsyncParsableCommand {
  @Option(help: "Specify name of an executable product to produce the bundle for.")
  var product: String?

  @Option(
    help: "Specify a path to a custom `index.html` file to be used for your app.",
    completion: .file(extensions: [".html"])
  )
  var customIndexPage: String?

  @Flag(help: "When specified, build in the debug mode.")
  var debug = false

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

  @OptionGroup()
  var buildOptions: BuildOptions

  static let configuration = CommandConfiguration(
    abstract: "Produces an optimized app bundle for distribution."
  )

  func buildFlavor() -> BuildFlavor {
    BuildFlavor(
      isRelease: !debug, environment: .defaultBrowser,
      sanitize: nil, swiftCompilerFlags: buildOptions.swiftCompilerFlags
    )
  }

  func run() async throws {
    let terminal = InteractiveWriter.stdout

    try dependency.check(on: localFileSystem, terminal)

    let toolchain = try await Toolchain(localFileSystem, terminal)

    let flavor = buildFlavor()
    let build = try await toolchain.buildCurrentProject(
      product: product,
      flavor: flavor
    )
    try terminal.logLookup(
      "Right after building the main binary size is ",
      localFileSystem.humanReadableFileSize(build.mainWasmPath),
      newline: true
    )

    if !debugInfo {
      try strip(build.mainWasmPath)
      try terminal.logLookup(
        "After stripping debug info the main binary size is ",
        localFileSystem.humanReadableFileSize(build.mainWasmPath),
        newline: true
      )
    }

    let bundleDirectory = AbsolutePath(localFileSystem.currentWorkingDirectory!, "Bundle")
    try localFileSystem.removeFileTree(bundleDirectory)
    try localFileSystem.createDirectory(bundleDirectory)

    let wasmOutputFilePath = AbsolutePath(bundleDirectory, "main.wasm")

    if wasmOptimizations == .size {
      try await optimize(build.mainWasmPath, outputPath: wasmOutputFilePath, terminal: terminal)
    } else {
      try localFileSystem.move(from: build.mainWasmPath, to: wasmOutputFilePath)
    }

    try copyToBundle(
      terminal: terminal,
      wasmOutputFilePath: wasmOutputFilePath,
      buildDirectory: build.mainWasmPath.parentDirectory,
      bundleDirectory: bundleDirectory,
      toolchain: toolchain,
      product: build.product
    )

    terminal.write("Bundle generation finished successfully\n", inColor: .green, bold: true)
  }

  func optimize(_ inputPath: AbsolutePath, outputPath: AbsolutePath, terminal: InteractiveWriter)
    async throws
  {
    var wasmOptArgs = ["wasm-opt", "-Os", inputPath.pathString, "-o", outputPath.pathString]
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

  func strip(_ wasmPath: AbsolutePath) throws {
    let binary = try localFileSystem.readFileContents(wasmPath)
    let strippedBinary = try stripCustomSections(binary.contents)
    try localFileSystem.writeFileContents(wasmPath, bytes: .init(strippedBinary))
  }

  func copyToBundle(
    terminal: InteractiveWriter,
    wasmOutputFilePath: AbsolutePath,
    buildDirectory: AbsolutePath,
    bundleDirectory: AbsolutePath,
    toolchain: SwiftToolchain.Toolchain,
    product: ProductDescription
  ) throws {
    // Rename the final binary to use a part of its hash to bust browsers and CDN caches.
    let wasmFileHash = try localFileSystem.readFileContents(wasmOutputFilePath).hexSHA256.prefix(16)
    let mainModuleName = "\(wasmFileHash).wasm"
    let mainModulePath = AbsolutePath(bundleDirectory, mainModuleName)
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
    let entrypointName = "\(entrypoint.hexSHA256.prefix(16)).js"
    try localFileSystem.writeFileContents(
      AbsolutePath(bundleDirectory, entrypointName),
      bytes: entrypoint
    )

    try localFileSystem.writeFileContents(
      AbsolutePath(bundleDirectory, "index.html"),
      bytes: ByteString(
        encodingAsUTF8: HTML.indexPage(
          customContent: HTML.readCustomIndexPage(at: customIndexPage, on: localFileSystem),
          entrypointName: entrypointName
        ))
    )

    let manifest = try toolchain.manifest.get()

    for directoryName in try localFileSystem.resourcesDirectoryNames(relativeTo: buildDirectory) {
      let resourcesPath = buildDirectory.appending(component: directoryName)
      let targetDirectory = bundleDirectory.appending(component: directoryName)

      guard localFileSystem.exists(resourcesPath) else { continue }
      terminal.logLookup("Copying resources to ", targetDirectory)
      try localFileSystem.copy(from: resourcesPath, to: targetDirectory)
    }

    /* While a product may be composed of multiple targets, not sure this is widely used in
     practice. Just assuming here that the first target of this product is an executable target,
     at least until SwiftPM allows specifying executable targets explicitly, as proposed in
     https://forums.swift.org/t/pitch-ability-to-declare-executable-targets-in-swiftpm-manifests-to-support-main/41968
     */
    let inferredMainTarget = manifest.targets.first {
      product.targets.contains($0.name)
    }

    guard let mainTarget = inferredMainTarget else { return }

    let targetPath = manifest.resourcesPath(for: mainTarget)
    let resourcesPath = buildDirectory.appending(component: targetPath)
    for file in try localFileSystem.traverseRecursively(resourcesPath) {
      let targetPath = bundleDirectory.appending(component: file.basename)

      guard localFileSystem.exists(resourcesPath) && !localFileSystem.exists(targetPath)
      else { continue }

      terminal.logLookup("Copying this resource to the root bundle directory ", file)
      try localFileSystem.copy(from: file, to: targetPath)
    }
  }
}
