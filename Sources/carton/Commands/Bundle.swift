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
import Crypto
import SwiftToolchain
import TSCBasic

private let dependency = Dependency(
  fileName: "bundle.js",
  sha256: bundleDependencySHA256
)

struct Bundle: ParsableCommand {
  @Option(help: "Specify name of an executable product to produce the bundle for.")
  var product: String?

  @Option(
    help: "Specify a path to a custom `index.html` file to be used for your app.",
    completion: .file(extensions: [".html"])
  )
  var customIndexPage: String?

  @Flag(help: "When specified, build in the debug mode.")
  var debug = false

  static let configuration = CommandConfiguration(
    abstract: "Produces an optimized app bundle for distribution."
  )

  func run() throws {
    let terminal = InteractiveWriter.stdout

    try dependency.check(on: localFileSystem, terminal)

    let toolchain = try Toolchain(localFileSystem, terminal)

    let (_, mainWasmPath) = try toolchain.buildCurrentProject(
      product: product,
      destination: nil,
      isRelease: !debug
    )
    try terminal.logLookup(
      "Right after building the main binary size is ",
      localFileSystem.humanReadableFileSize(mainWasmPath),
      newline: true
    )

    try ProcessRunner(["wasm-strip", mainWasmPath.pathString], terminal).waitUntilFinished()
    try terminal.logLookup(
      "After applying `wasm-strip` the main binary size is ",
      localFileSystem.humanReadableFileSize(mainWasmPath),
      newline: true
    )

    let bundleDirectory = AbsolutePath(localFileSystem.currentWorkingDirectory!, "Bundle")
    try localFileSystem.removeFileTree(bundleDirectory)
    try localFileSystem.createDirectory(bundleDirectory)
    let optimizedPath = AbsolutePath(bundleDirectory, "main.wasm")
    try ProcessRunner(
      ["wasm-opt", "-Os", mainWasmPath.pathString, "-o", optimizedPath.pathString],
      terminal
    ).waitUntilFinished()
    try terminal.logLookup(
      "After applying `wasm-opt` the main binary size is ",
      localFileSystem.humanReadableFileSize(optimizedPath),
      newline: true
    )

    try copyToBundle(
      terminal: terminal,
      optimizedPath: optimizedPath,
      buildDirectory: mainWasmPath.parentDirectory,
      bundleDirectory: bundleDirectory,
      toolchain: toolchain
    )

    terminal.write("Bundle generation finished successfully\n", inColor: .green, bold: true)
  }

  func copyToBundle(
    terminal: InteractiveWriter,
    optimizedPath: AbsolutePath,
    buildDirectory: AbsolutePath,
    bundleDirectory: AbsolutePath,
    toolchain: Toolchain
  ) throws {
    // Rename the final binary to use a part of its hash to bust browsers and CDN caches.
    let optimizedHash = try localFileSystem.readFileContents(optimizedPath).hexSHA256.prefix(16)
    let mainModuleName = "\(optimizedHash).wasm"
    let mainModulePath = AbsolutePath(bundleDirectory, mainModuleName)
    try localFileSystem.move(from: optimizedPath, to: mainModulePath)

    // Copy the bundle entrypoint, point to the binary, and give it a cachebuster name.
    let (_, _, entrypointPath) = dependency.paths(on: localFileSystem)
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
      bytes: ByteString(encodingAsUTF8: HTML.indexPage(
        customContent: HTML.readCustomIndexPage(at: customIndexPage, on: localFileSystem),
        entrypointName: entrypointName
      ))
    )

    let package = try toolchain.package.get()
    for target in package.targets where target.type == .regular && !target.resources.isEmpty {
      let targetPath = package.resourcesPath(for: target)
      let resourcesPath = buildDirectory.appending(component: targetPath)
      let targetDirectory = bundleDirectory.appending(component: targetPath)

      guard localFileSystem.exists(resourcesPath) else { continue }
      terminal.logLookup("Copying resources to ", targetDirectory)
      try localFileSystem.copy(from: resourcesPath, to: targetDirectory)
    }
  }
}
