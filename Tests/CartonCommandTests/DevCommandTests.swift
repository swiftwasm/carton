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

@testable import CartonFrontend

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

final class DevCommandTests: XCTestCase {
  private var client: URLSession?

  #if os(macOS)
    func testWithNoArguments() async throws {
      // FIXME: Don't assume a specific port is available since it can be used by others or tests
      try await withFixture("EchoExecutable") { packageDirectory in
        let process = try swiftRunProcess(
          ["carton", "dev", "--verbose", "--skip-auto-open"],
          packageDirectory: packageDirectory.url
        )

        await checkForExpectedContent(process: process, at: "http://127.0.0.1:8080")
      }
    }

    func testWithArguments() async throws {
      // FIXME: Don't assume a specific port is available since it can be used by others or tests
      try await withFixture("EchoExecutable") { packageDirectory in
        let process = try swiftRunProcess(
          ["carton", "dev", "--verbose", "--port", "8081", "--skip-auto-open"],
          packageDirectory: packageDirectory.url
        )

        await checkForExpectedContent(process: process, at: "http://127.0.0.1:8081")
      }
    }
  #endif

  func checkForExpectedContent(process: SwiftRunProcess, at url: String) async {
    // client time out for connecting and responding
    let timeOut: Int64 = 60

    // client delay... let the server start up
    let delay: UInt32 = 30

    // only try 5 times.
    let polls = 5

    let expectedHtml =
      """
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <script type="module" src="dev.js"></script>
        </head>
        <body>
        </body>
      </html>
      """

    client = .shared

    var response: HTTPURLResponse?
    var responseBody: Data?
    var count = 0

    // give the server some time to start
    repeat {
      sleep(delay)
      count += 1

      guard
        let (body, urlResponse) = try? await client?.data(
          for: URLRequest(
            url: URL(string: url)!,
            cachePolicy: .reloadIgnoringCacheData,
            timeoutInterval: TimeInterval(timeOut)
          )
        )
      else {
        continue
      }
      response = urlResponse as? HTTPURLResponse
      responseBody = body
    } while count < polls && response == nil

    // end the process regardless of success
    process.process.signal(SIGTERM)

    if let response = response {
      XCTAssertTrue(response.statusCode == 200, "Response was not ok")

      guard let data = responseBody else {
        XCTFail("Could not map data")
        return
      }
      guard let actualHtml = String(data: data, encoding: .utf8) else {
        XCTFail("Could not convert data to string")
        return
      }

      // test may be brittle as the template may change over time.
      XCTAssertEqual(actualHtml, expectedHtml, "HTML output does not match")

    } else {
      print("no response from server after \(count) tries or \(Int(count) * Int(delay)) seconds")
      XCTFail("Could not reach server")
    }
  }
}
