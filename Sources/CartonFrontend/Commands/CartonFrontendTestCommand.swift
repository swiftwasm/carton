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
import CartonCore
import Foundation

enum SanitizeVariant: String, CaseIterable, ExpressibleByArgument {
  case stackOverflow
}

struct TestError: Error, CustomStringConvertible {
  let description: String
}

struct CartonFrontendTestCommand: AsyncParsableCommand {

  static let configuration = CommandConfiguration(
    commandName: "test",
    abstract: "Run the tests in a WASI environment."
  )

  @Flag(help: "When specified, build in the release mode.")
  var release = false

  @Flag(name: .shortAndLong, help: "When specified, list all available test cases.")
  var list = false

  @Option(name: .long, help: ArgumentHelp(
    """
    Pass an environment variable to the test process.
    --env NAME=VALUE will set the environment variable NAME to VALUE.
    --env NAME will inherit the environment variable NAME from the parent process.
    """,
    valueName: "NAME=VALUE or NAME"
  ), transform: Self.parseEnvOption(_:))
  var env: [(key: String, value: String?)] = []

  static func parseEnvOption(_ value: String) -> (key: String, value: String?) {
    let parts = value.split(separator: "=", maxSplits: 1)
    if parts.count == 1 {
      return (String(parts[0]), nil)
    }
    return (String(parts[0]), String(parts[1]))
  }

  @Argument(help: "The list of test cases to run in the test suite.")
  var testCases = [String]()

  @Option(
    help:
      "Environment used to run the tests. Available values: \(Environment.allCasesNames.joined(separator: ", "))"
  )
  private var environment = Environment.command

  /// It is implemented as a separate flag instead of a `--environment` variant because `--environment`
  /// is designed to accept specific browser names in the future like `--environment firefox`.
  /// Then `--headless` should be able to be used with `defaultBrowser` and other browser values.
  @Flag(help: "When running browser tests, run the browser in headless mode")
  var headless: Bool = false

  @Option(help: "Turn on runtime checks for various behavior.")
  private var sanitize: SanitizeVariant?

  @Option(
    name: .shortAndLong,
    help: """
      Set the address where the development server will listen for connections.
      """
  )
  var bind: String = "0.0.0.0"

  @Option(
    name: .shortAndLong,
    help: "Set the HTTP port the testing server will run on for browser environment."
  )
  var port = 8080

  @Option(
    name: .shortAndLong,
    help: """
      Set the location where the development server will run.
      The default value is derived from the –-bind option.
      """
  )
  var host: String?

  @Option(help: "Use the given bundle instead of building the test target")
  var prebuiltTestBundlePath: String

  @Option(
    name: .long,
    help: ArgumentHelp(
      "Internal: Path to resources directory built by the SwiftPM Plugin process.",
      visibility: .private
    )
  )
  var resources: [String] = []

  @Option(name: .long, help: ArgumentHelp(
    "Internal: Path to writable directory", visibility: .private
  ))
  var pluginWorkDirectory: String = "./"

  @Option(name: .long, help: .hidden) var pid: Int32?

  func validate() throws {
    if headless && environment != .browser {
      throw TestError(
        description: "The `--headless` flag can be applied only for browser environments")
    }
  }

  func run() async throws {
    let terminal = InteractiveWriter.stdout
    let bundlePath: AbsolutePath
    let cwd = localFileSystem.currentWorkingDirectory!
    bundlePath = try AbsolutePath(
      validating: prebuiltTestBundlePath, relativeTo: cwd)
    guard localFileSystem.exists(bundlePath, followSymlink: true) else {
      terminal.write(
        "No prebuilt binary found at \(bundlePath)\n",
        inColor: .red
      )
      throw ExitCode.failure
    }

    let runner = try deriveRunner(bundlePath: bundlePath, terminal: terminal, cwd: cwd)
    let options = deriveRunnerOptions()
    try await runner.run(options: options)
  }

  func deriveRunner(
    bundlePath: AbsolutePath,
    terminal: InteractiveWriter,
    cwd: AbsolutePath
  ) throws -> TestRunner {
    switch environment {
    case .command:
      return CommandTestRunner(
        testFilePath: bundlePath,
        listTestCases: list,
        testCases: testCases,
        terminal: terminal
      )
    case .browser:
      return BrowserTestRunner(
        testFilePath: bundlePath,
        bindingAddress: bind,
        host: Server.Configuration.host(bindOption: bind, hostOption: host),
        port: port,
        headless: headless,
        resourcesPaths: resources,
        pid: pid,
        terminal: terminal
      )
    case .node:
      return try NodeTestRunner(
        pluginWorkDirectory: AbsolutePath(validating: pluginWorkDirectory, relativeTo: cwd),
        testFilePath: bundlePath,
        listTestCases: list,
        testCases: testCases,
        terminal: terminal
      )
    }
  }

  func deriveRunnerOptions() -> TestRunnerOptions {
    let parentEnv = ProcessInfo.processInfo.environment
    var env: [String: String] = parentEnv
    for (key, value) in self.env {
      if let value = value {
        env[key] = value
      } else {
        env[key] = parentEnv[key]
      }
    }
    return TestRunnerOptions(env: env)
  }
}
