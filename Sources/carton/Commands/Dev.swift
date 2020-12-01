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

struct Dev: ParsableCommand {
  static let entrypoint = Entrypoint(fileName: "dev.js", sha256: devEntrypointSHA256)

  @Option(help: "Specify name of an executable product in development.")
  var product: String?

  @Option(
    help: "This option has no effect and will be removed in a future version of `carton`"
  )
  var destination: String?

  @Option(help: "Specify a path to a custom `index.html` file to be used for your app.")
  var customIndexPage: String?

  @Flag(help: "When specified, build in the release mode.")
  var release = false

  @Flag(name: .shortAndLong, help: "Don't clear terminal window after files change.")
  var verbose = false

  @Option(name: .shortAndLong, help: "Set the HTTP port the development server will run on.")
  var port = 8080

  @Flag(name: .long, help: "Skip automatically opening app in system browser.")
  var skipAutoOpen = false

  static let configuration = CommandConfiguration(
    abstract: "Watch the current directory, host the app, rebuild on change."
  )

  func run() throws {
    let terminal = InteractiveWriter.stdout

    try Self.entrypoint.check(on: localFileSystem, terminal)

    let toolchain = try Toolchain(localFileSystem, terminal)

    if !verbose {
      terminal.clearWindow()
      terminal.saveCursor()
    }

    if destination != nil {
      terminal.write(
        """
        --destination option is no longer needed when using latest SwiftWasm toolchains. \
        This option no longer has any effect and will be removed in a future version of `carton`. \
        You should be able to link with Foundation/XCTest without passing this option. If it is \
        still required in your build process for some reason, please report it as a bug at \
        https://github.com/swiftwasm/swift/issues/\n
        """,
        inColor: .red
      )
    }

    let (arguments, mainWasmPath, inferredProduct) = try toolchain.buildCurrentProject(
      product: product,
      isRelease: release
    )

    let paths = try toolchain.inferSourcesPaths()

    if !verbose {
      terminal.revertCursorAndClear()
    }
    terminal.write("\nWatching these directories for changes:\n", inColor: .green)
    paths.forEach { terminal.logLookup("", $0) }
    terminal.write("\n")

    let sources = try paths.flatMap { try localFileSystem.traverseRecursively($0) }

    try Server(
      with: .init(
        builder: Builder(
          arguments: arguments,
          mainWasmPath: mainWasmPath,
          pathsToWatch: sources,
          localFileSystem,
          terminal
        ),
        mainWasmPath: mainWasmPath,
        verbose: verbose,
        skipAutoOpen: skipAutoOpen,
        port: port,
        customIndexContent: HTML.readCustomIndexPage(at: customIndexPage, on: localFileSystem),
        // swiftlint:disable:next force_try
        package: try! toolchain.package.get(),
        product: inferredProduct,
        entrypoint: Self.entrypoint
      ),
      terminal
    ).run()
  }
}
