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
    guard let terminal = TerminalController(stream: stdoutStream)
    else { fatalError("failed to create an instance of `TerminalController`") }

    try dependency.check(on: localFileSystem, terminal)

    let toolchain = try Toolchain(localFileSystem, terminal)

    let (_, mainWasmPath) = try toolchain.buildCurrentProject(
      product: product,
      destination: nil,
      isRelease: !debug
    )
    try terminal.logLookup(
      "Right after building the main binary size is ",
      localFileSystem.humanReadableFileSize(mainWasmPath)
    )

    try ProcessRunner(["wasm-strip", mainWasmPath.pathString], terminal).waitUntilFinished()
    try terminal.logLookup(
      "After applying `wasm-strip` the main binary size is ",
      localFileSystem.humanReadableFileSize(mainWasmPath)
    )

    let bundleDir = AbsolutePath(localFileSystem.currentWorkingDirectory!, "Bundle")
    try localFileSystem.removeFileTree(bundleDir)
    try localFileSystem.createDirectory(bundleDir)
    let optimizedPath = AbsolutePath(bundleDir, "main.wasm")
    try ProcessRunner(
      ["wasm-opt", "-Os", mainWasmPath.pathString, "-o", optimizedPath.pathString],
      terminal
    ).waitUntilFinished()
    try terminal.logLookup(
      "After applying `wasm-opt` the main binary size is ",
      localFileSystem.humanReadableFileSize(optimizedPath)
    )

    // Rename the final binary to use a part of its hash to bust browsers and CDN caches.
    let optimizedHash = try ByteString(SHA256.hash(data:
      localFileSystem.readFileContents(optimizedPath).contents
    )).hexadecimalRepresentation.prefix(16)
    let mainModuleName = "\(optimizedHash).wasm"
    let mainModulePath = AbsolutePath(bundleDir, mainModuleName)
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
    let entrypointName =
      """
      \(ByteString(SHA256.hash(data: entrypoint.contents)).hexadecimalRepresentation.prefix(16)).js
      """
    try localFileSystem.writeFileContents(
      AbsolutePath(bundleDir, entrypointName),
      bytes: entrypoint
    )

    try localFileSystem.writeFileContents(
      AbsolutePath(bundleDir, "index.html"),
      bytes: ByteString(encodingAsUTF8: HTML.indexPage(
        customContent: HTML.readCustomIndexPage(at: customIndexPage, on: localFileSystem),
        entrypointName: entrypointName
      ))
    )

    terminal.write("\nBundle generation finished successfully", inColor: .green, bold: true)
  }
}
