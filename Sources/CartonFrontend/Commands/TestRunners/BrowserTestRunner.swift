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

import CartonHelpers
import CartonKit
import Foundation
import NIOCore
import NIOPosix
import WebDriver

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

private enum Constants {
  static let entrypoint = Entrypoint(fileName: "test.js", content: StaticResource.test)
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
  let bindingAddress: String
  let host: String
  let port: Int
  let headless: Bool
  let resourcesPaths: [String]
  let pid: Int32?
  let terminal: InteractiveWriter
  let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

  init(
    testFilePath: AbsolutePath,
    bindingAddress: String,
    host: String,
    port: Int,
    headless: Bool,
    resourcesPaths: [String],
    pid: Int32?,
    terminal: InteractiveWriter
  ) {
    self.testFilePath = testFilePath
    self.bindingAddress = bindingAddress
    self.host = host
    self.port = port
    self.headless = headless
    self.resourcesPaths = resourcesPaths
    self.pid = pid
    self.terminal = terminal
  }

  func run() async throws {
    let server = try await Server(
      .init(
        builder: nil,
        mainWasmPath: testFilePath,
        verbose: true,
        bindingAddress: bindingAddress,
        port: port,
        host: host,
        customIndexPath: nil,
        resourcesPaths: resourcesPaths,
        entrypoint: Constants.entrypoint,
        pid: pid,
        terminal: terminal
      )
    )
    let localURL = try await server.start()
    var disposer: () async throws -> Void = {}
    do {
      if headless {
        let webDriver = try await WebDriverServices.find(terminal: terminal)
        let client = try await webDriver.client()
        disposer = {
          try await client.closeSession()
          webDriver.dispose()
        }
        try await client.goto(url: localURL)
      } else {
        disposer = {}
        try openInSystemBrowser(url: localURL)
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
