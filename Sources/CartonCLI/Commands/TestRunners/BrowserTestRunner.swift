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

import AsyncHTTPClient
import CartonHelpers
import CartonKit
import Foundation
import NIOCore
import NIOPosix
import PackageModel
import TSCBasic
import WebDriverClient

private enum Constants {
  static let entrypoint = Entrypoint(fileName: "test.js", sha256: testEntrypointSHA256)
}

enum BrowserTestRunnerError: Error, CustomStringConvertible {
  case invalidRemoteURL(String)
  case failedToFindWebDriver

  var description: String {
    switch self {
    case let .invalidRemoteURL(url): return "Invalid remote URL: \(url)"
    case .failedToFindWebDriver:
      return """
      Failed to find WebDriver executable or remote URL to a running driver process.
      Please make sure that you are satisfied with one of the followings (in order of priority)
      1. Set `WEBDRIVER_REMOTE_URL` with the address of remote WebDriver like `WEBDRIVER_REMOTE_URL=http://localhost:9515`.
      2. Set `WEBDRIVER_PATH` with the path to your WebDriver executable.
      3. `chromedriver`, `geckodriver`, `safaridriver`, or `msedgedriver` has been installed in `PATH`
      """
    }
  }
}

struct BrowserTestRunner: TestRunner {
  let testFilePath: AbsolutePath
  let host: String
  let port: Int
  let headless: Bool
  let manifest: Manifest
  let terminal: InteractiveWriter
  let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  let httpClient: HTTPClient

  init(
    testFilePath: AbsolutePath,
    host: String,
    port: Int,
    headless: Bool,
    manifest: Manifest,
    terminal: InteractiveWriter
  ) {
    self.testFilePath = testFilePath
    self.host = host
    self.port = port
    self.headless = headless
    self.manifest = manifest
    self.terminal = terminal
    httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
  }

  typealias Disposer = () -> ()

  func findAvailablePort() async throws -> SocketAddress {
    let bootstrap = ServerBootstrap(group: eventLoopGroup)
    let address = try SocketAddress.makeAddressResolvingHost("127.0.0.1", port: 0)
    let channel = try await bootstrap.bind(to: address).get()
    let localAddr = channel.localAddress!
    try await channel.close()
    return localAddr
  }

  func launchDriver(executablePath: String) async throws -> (URL, Disposer) {
    let address = try await findAvailablePort()
    let process = Process(arguments: [
      executablePath, "--port=\(address.port!)",
    ])
    terminal.logLookup("Launch WebDriver executable: ", executablePath)
    try process.launch()
    let disposer = { process.signal(SIGKILL) }
    return (URL(string: "http://\(address.ipAddress!):\(address.port!)")!, disposer)
  }

  func selectWebDriver() async throws -> (URL, Disposer) {
    let strategies: [() async throws -> (URL, Disposer)?] = [
      {
        terminal.logLookup("- checking WebDriver endpoint: ", "WEBDRIVER_REMOTE_URL")
        guard let value = ProcessInfo.processInfo.environment["WEBDRIVER_REMOTE_URL"] else {
          return nil
        }
        guard let url = URL(string: value) else {
          throw BrowserTestRunnerError.invalidRemoteURL(value)
        }
        return (url, {})
      },
      {
        terminal.logLookup("- checking WebDriver executable: ", "WEBDRIVER_PATH")
        guard let executable = ProcessEnv.vars["WEBDRIVER_PATH"] else {
          return nil
        }
        let (url, disposer) = try await launchDriver(executablePath: executable)
        return (url, disposer)
      },
      {
        let driverCandidates = [
          "chromedriver", "geckodriver", "safaridriver", "msedgedriver",
        ]
        terminal.logLookup("- checking WebDriver executable in PATH: ", driverCandidates.joined(separator: ", "))
        guard let found = driverCandidates.lazy.compactMap({ Process.findExecutable($0) }).first else {
          return nil
        }
        return try await launchDriver(executablePath: found.pathString)
      },
    ]
    for strategy in strategies {
      if let (url, disposer) = try await strategy() {
        return (url, disposer)
      }
    }
    throw BrowserTestRunnerError.failedToFindWebDriver
  }

  func run() async throws {
    defer { try httpClient.syncShutdown() }
    try Constants.entrypoint.check(on: localFileSystem, terminal)
    let server = try await Server(
      .init(
        builder: nil,
        mainWasmPath: testFilePath,
        verbose: true,
        port: port,
        host: host,
        customIndexPath: nil,
        manifest: manifest,
        product: nil,
        entrypoint: Constants.entrypoint,
        terminal: terminal
      ),
      .shared(eventLoopGroup)
    )
    let localURL = try await server.start()
    var disposer: () async throws -> () = {}
    do {
      if headless {
        let (endpoint, clientDisposer) = try await selectWebDriver()
        let client = try await WebDriverClient.newSession(endpoint: endpoint, httpClient: httpClient)
        disposer = {
          try await client.closeSession()
          clientDisposer()
        }
        try await client.goto(url: localURL)
      } else {
        disposer = {}
        openInSystemBrowser(url: localURL)
      }
      let hadError = try await server.waitUntilTestFinished()
      try await disposer()
      exit(hadError ? EXIT_FAILURE : EXIT_SUCCESS)
    } catch {
      try await disposer()
      throw error
    }
  }
}
