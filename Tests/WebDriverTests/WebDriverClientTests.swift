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

import CartonHelpers
import WebDriver
import XCTest

final class WebDriverClientTests: XCTestCase {
  #if canImport(FoundationNetworking)
  #else
  func testGotoURLSession() async throws {
    let terminal = InteractiveWriter.stdout
    let service = try await WebDriverServices.find(terminal: terminal)
    defer {
      service.dispose()
    }

    let client = try await service.client(
      httpClient: URLSessionWebDriverHTTPClient(session: .shared)
    )
    try await client.goto(url: URL(string: "https://example.com")!)
    try await client.closeSession()
  }
  #endif

  func testGotoCurl() async throws {
    let terminal = InteractiveWriter.stdout
    let service = try await WebDriverServices.find(terminal: terminal)
    defer {
      service.dispose()
    }

    let client = try await service.client(
      httpClient: try XCTUnwrap(CurlWebDriverHTTPClient.find())
    )
    try await client.goto(url: URL(string: "https://example.com")!)
    try await client.closeSession()
  }
}
