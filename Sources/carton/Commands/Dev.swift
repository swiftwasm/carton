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
import Foundation
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif
import SwiftToolchain
import TSCBasic

private let dependency = Dependency(
  fileName: "dev.js",
  sha256: ByteString([
    0xFA, 0x06, 0xE2, 0xA3, 0x2D, 0x45, 0xB9, 0xBB, 0x95, 0x9A, 0x89, 0x64, 0x3F, 0x6D, 0xAF, 0x1C,
    0xF5, 0x49, 0xFC, 0x34, 0x59, 0xC5, 0xE0, 0xA6, 0x01, 0x59, 0xEB, 0x0C, 0xE6, 0xB2, 0x0B, 0x0C,
  ])
)

struct Dev: ParsableCommand {
  @Option(help: "Specify name of an executable product in development.")
  var product: String?

  @Option(help: "Specify name of a json destination file to be passed to `swift build`.")
  var destination: String?

  @Flag(help: "When specified, will build in release mode.")
  var release = false

  static var configuration = CommandConfiguration(
    abstract: "Watch the current directory, host the app, rebuild on change."
  )

  func run() throws {
    guard let terminal = TerminalController(stream: stdoutStream)
    else { fatalError("failed to create an instance of `TerminalController`") }

    try dependency.check(on: localFileSystem, terminal)

    let toolchain = try Toolchain(localFileSystem, terminal)

    let (arguments, mainWasmPath) = try toolchain.buildCurrentProject(
      product: product,
      destination: destination,
      release: release
    )

    let sources = try toolchain.inferSourcesPaths().map { source -> [AbsolutePath] in
      let relativePath = try RelativePath(validating: source)
      guard let sources = localFileSystem.currentWorkingDirectory?.appending(relativePath)
      else { fatalError("failed to infer the sources directory") }

      terminal.write("\nWatching this directory for changes: ", inColor: .green)
      terminal.logLookup("", sources)
      terminal.write("\n")

      return try localFileSystem.traverseRecursively(sources)
    }.flatMap { $0 }

    try Server(
      builderArguments: arguments,
      pathsToWatch: sources,
      mainWasmPath: mainWasmPath.pathString,
      terminal
    ).run()
  }
}
