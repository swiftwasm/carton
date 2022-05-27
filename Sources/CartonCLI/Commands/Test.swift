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
import SwiftToolchain
import TSCBasic

extension Environment: ExpressibleByArgument {}

extension SanitizeVariant: ExpressibleByArgument {}

struct Test: AsyncParsableCommand {

  static let configuration = CommandConfiguration(abstract: "Run the tests in a WASI environment.")

  @Flag(help: "When specified, build in the release mode.")
  var release = false

  @Flag(name: .shortAndLong, help: "When specified, list all available test cases.")
  var list = false

  @Argument(help: "The list of test cases to run in the test suite.")
  var testCases = [String]()

  @Option(
    help:
      "Environment used to run the tests. Available values: \(Environment.allCasesNames.joined(separator: ", "))"
  )
  private var environment = Environment.wasmer

  @Option(help: "Turn on runtime checks for various behavior.")
  private var sanitize: SanitizeVariant?

  @Option(
    name: .shortAndLong,
    help: "Set the HTTP port the testing server will run on for browser environment."
  )
  var port = 8080

  @Option(
    name: .shortAndLong,
    help: "Set the location where the testing server will run. Default is `127.0.0.1`."
  )
  var host = "127.0.0.1"

  @Flag(name: .customLong("skip-build"),
        help: "Skip building the test target")
  var shouldSkipBuilding: Bool = false

  @OptionGroup()
  var buildOptions: BuildOptions

  private var buildFlavor: BuildFlavor {
    BuildFlavor(
      isRelease: release,
      environment: environment,
      sanitize: sanitize,
      swiftCompilerFlags: buildOptions.swiftCompilerFlags
    )
  }

  func run() async throws {
    let terminal = InteractiveWriter.stdout
    let toolchain = try await Toolchain(localFileSystem, terminal)
    let bundlePath: AbsolutePath
    if shouldSkipBuilding {
      bundlePath = try toolchain.getTestProduct(flavor: buildFlavor).artifactPath
      guard localFileSystem.exists(bundlePath) else {
        terminal.write(
          "No built binary found in \(bundlePath)\n",
          inColor: .red
        )
        throw ExitCode.failure
      }
    } else {
      bundlePath = try await toolchain.buildTestBundle(flavor: buildFlavor)
    }

    switch environment {
    case .wasmer:
      try await WasmerTestRunner(
        testFilePath: bundlePath,
        listTestCases: list,
        testCases: testCases,
        terminal: terminal
      ).run()
    case .defaultBrowser:
      try await BrowserTestRunner(
        testFilePath: bundlePath,
        host: host,
        port: port,
        // swiftlint:disable:next force_try
        manifest: try! toolchain.manifest.get(),
        terminal: terminal
      ).run()
    case .node:
      try await NodeTestRunner(
        testFilePath: bundlePath,
        listTestCases: list,
        testCases: testCases,
        terminal: terminal
      ).run()
    }
  }
}
