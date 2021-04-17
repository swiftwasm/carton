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
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif
import CartonHelpers
import CartonKit
import SwiftToolchain
import TSCBasic

private enum Environment: String, CaseIterable, ExpressibleByArgument {
  case wasmer
  case defaultBrowser

  var destination: DestinationEnvironment {
    switch self {
    case .defaultBrowser:
      return .browser
    case .wasmer:
      return .other
    }
  }
}

extension SanitizeVariant: ExpressibleByArgument {}

struct Test: ParsableCommand {
  static let entrypoint = Entrypoint(fileName: "test.js", sha256: testEntrypointSHA256)

  static let configuration = CommandConfiguration(abstract: "Run the tests in a WASI environment.")

  @Flag(help: "When specified, build in the release mode.")
  var release = false

  @Flag(name: .shortAndLong, help: "When specified, list all available test cases.")
  var list = false

  @Argument(help: "The list of test cases to run in the test suite.")
  var testCases = [String]()

  @Option(help: "Environment used to run the tests, either a browser, or command-line Wasm host.")
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

  func buildFlavor() -> BuildFlavor {
    let defaultSanitize: SanitizeVariant? = release ? nil : .stackOverflow
    return BuildFlavor(
      isRelease: release, environment: environment.destination,
      sanitize: sanitize ?? defaultSanitize
    )
  }

  func run() throws {
    let terminal = InteractiveWriter.stdout

    try Self.entrypoint.check(on: localFileSystem, terminal)
    let toolchain = try Toolchain(localFileSystem, terminal)
    let flavor = buildFlavor()
    let testBundlePath = try toolchain.buildTestBundle(flavor: flavor)

    if environment == .wasmer {
      terminal.write("\nRunning the test bundle with wasmer:\n", inColor: .yellow)
      var wasmerArguments = ["wasmer", testBundlePath.pathString]
      if list {
        wasmerArguments.append(contentsOf: ["--", "-l"])
      } else if !testCases.isEmpty {
        wasmerArguments.append("--")
        wasmerArguments.append(contentsOf: testCases)
      }
      let runner = ProcessRunner(wasmerArguments, parser: TestsParser(), terminal)

      try runner.waitUntilFinished()
    } else {
      try Server(
        with: .init(
          builder: nil,
          mainWasmPath: testBundlePath,
          verbose: true,
          skipAutoOpen: false,
          port: port,
          host: host,
          customIndexContent: nil,
          // swiftlint:disable:next force_try
          manifest: try! toolchain.manifest.get(),
          product: nil,
          entrypoint: Self.entrypoint
        ),
        terminal
      ).run()
    }
  }
}
