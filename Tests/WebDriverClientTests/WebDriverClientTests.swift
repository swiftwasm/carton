// Copyright 2022 Carton contributors
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
import WebDriverClient
import XCTest

final class WebDriverClientTests: XCTestCase {
  let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)

  override func tearDown() async throws {
    try httpClient.syncShutdown()
  }

  func checkRemoteURL() throws -> URL {
    guard let value = ProcessInfo.processInfo.environment["WEBDRIVER_REMOTE_URL"] else {
      throw XCTSkip("Skip WebDriver tests due to no WEBDRIVER_REMOTE_URL env var")
    }
    return try XCTUnwrap(URL(string: value), "Invalid URL string: \(value)")
  }

  func testGoto() async throws {
    let client = try await WebDriverClient.newSession(
      endpoint: checkRemoteURL(), httpClient: httpClient
    )
    try await client.goto(url: "https://example.com")
    try await client.closeSession()
  }
}
