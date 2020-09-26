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
  sha256: devDependencySHA256
)

struct Dev: ParsableCommand {
  @Option(help: "Specify name of an executable product in development.")
  var product: String?

  @Option(help: "Specify name of a json destination file to be passed to `swift build`.")
  var destination: String?

  @Option(help: "Specify a path to a custom `index.html` file to be used for your app.")
  var customIndexPage: String?

  @Flag(help: "When specified, build in the release mode.")
  var release = false

  @Flag(name: .shortAndLong, help: "Don't clear terminal window after files change.")
  var verbose = false

  static let configuration = CommandConfiguration(
    abstract: "Watch the current directory, host the app, rebuild on change."
  )

  func run() throws {
    let terminal = InteractiveWriter.stdout

    try dependency.check(on: localFileSystem, terminal)

    let toolchain = try Toolchain(localFileSystem, terminal)

    let (arguments, mainWasmPath) = try toolchain.buildCurrentProject(
      product: product,
      destination: destination,
      isRelease: release
    )

    let paths = try toolchain.inferSourcesPaths()

    if !verbose {
      terminal.clearWindow()
      terminal.homeAndClear()
    }
    terminal.write("\nWatching these directories for changes:\n", inColor: .green)
    paths.forEach { terminal.logLookup("", $0) }
    terminal.write("\n")

    let sources = try paths.flatMap { try localFileSystem.traverseRecursively($0) }

    try Server(
      builderArguments: arguments,
      pathsToWatch: sources,
      mainWasmPath: mainWasmPath,
      customIndexContent: HTML.readCustomIndexPage(at: customIndexPage, on: localFileSystem),
      // swiftlint:disable:next force_try
      package: try! toolchain.package.get(),
      verbose: verbose,
      terminal
    ).run()
  }
}
