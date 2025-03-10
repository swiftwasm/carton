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
//
//  Created by Cavelle Benjamin on Dec/20/20.
//

import Foundation
import XCTest
import CartonHelpers

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

final class DevCommandTests: XCTestCase {
  #if os(macOS)
    func testWithNoArguments() async throws {
      // FIXME: Don't assume a specific port is available since it can be used by others or tests
      try await withFixture("EchoExecutable") { packageDirectory in
        let process = try swiftRunProcess(
          ["carton", "dev", "--verbose"],
          packageDirectory: packageDirectory.asURL
        )

        try await checkForExpectedContent(process: process, at: "http://localhost:8080")
      }
    }

    func testWithArguments() async throws {
      // FIXME: Don't assume a specific port is available since it can be used by others or tests
      try await withFixture("EchoExecutable") { packageDirectory in
        let process = try swiftRunProcess(
          ["carton", "dev", "--verbose", "--port", "8080"],
          packageDirectory: packageDirectory.asURL
        )

        try await checkForExpectedContent(process: process, at: "http://localhost:8080")
      }
    }
  #endif

  private func fetchDevServerWithRetry(at url: URL) async throws -> (response: HTTPURLResponse, body: Data) {
    // client time out for connecting and responding
    let timeOut: Duration = .seconds(10)

    // client delay... let the server start up
    let delay: Duration = .seconds(3)

    let count = 100

    do {
      return try await withRetry(maxAttempts: count, initialDelay: delay, retryInterval: delay) {
        try await fetchWebContent(at: url, timeout: timeOut)
      }
    } catch {
      throw CommandTestError(
        "Could not reach server.\n" +
        "No response from server after \(count) tries or \(count * Int(delay.components.seconds)) seconds.\n" +
        "Last error: \(error)"
      )
    }
  }

  func checkForExpectedContent(process: SwiftRunProcess, at url: String) async throws {
    defer {
      // end the process regardless of success
      process.process.signal(SIGINT)
    }

    let (response, data) = try await fetchDevServerWithRetry(at: try URL(string: url).unwrap("url"))
    XCTAssertEqual(response.statusCode, 200, "Response was not ok")

    let expectedHtml = """
      <!DOCTYPE html>
      <html>
        <head>
          <script type="module" src="/@vite/client"></script>

          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <script type="module" src="app.js"></script>
        </head>
        <body>
        </body>
      </html>
      """

    guard let actualHtml = String(data: data, encoding: .utf8) else {
      throw CommandTestError("Could not decode as UTF-8 string")
    }

    // test may be brittle as the template may change over time.
    XCTAssertEqual(actualHtml, expectedHtml, "HTML output does not match")
  }
}
