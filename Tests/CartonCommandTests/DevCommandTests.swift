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

import AsyncHTTPClient
@testable import CartonCLI
import XCTest

final class DevCommandTests: XCTestCase {
  private var client: HTTPClient?

  override func tearDown() {
    try? client?.syncShutdown()
    client = nil
  }

  #if os(macOS)
  func testWithNoArguments() throws {
    // FIXME: Don't assume a specific port is available since it can be used by others or tests
    try withFixture("EchoExecutable") { packageDirectory in
      guard let process = executeCommand(
        command: "carton dev --verbose",
        shouldPrintOutput: true,
        cwd: packageDirectory.url
      ) else {
        XCTFail("Could not create process")
        return
      }

      checkForExpectedContent(process: process, at: "http://127.0.0.1:8080")
    }
  }

  func testWithArguments() throws {
    // FIXME: Don't assume a specific port is available since it can be used by others or tests
    try withFixture("EchoExecutable") { packageDirectory in
      guard let process = executeCommand(
        command: "carton dev --verbose --port 8081",
        shouldPrintOutput: true,
        cwd: packageDirectory.url
      ) else {
        XCTFail("Could not create process")
        return
      }

      checkForExpectedContent(process: process, at: "http://127.0.0.1:8081")
    }
  }
  #endif

  func checkForExpectedContent(process: Process, at url: String) {
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

    let timeout = HTTPClient.Configuration.Timeout(
      connect: .seconds(timeOut),
      read: .seconds(timeOut)
    )

    client = HTTPClient(eventLoopGroupProvider: .createNew,
                        configuration: HTTPClient.Configuration(timeout: timeout))

    var response: HTTPClient.Response?
    var count = 0

    // give the server some time to start
    repeat {
      // Don't wait for anything if the process is dead.
      guard process.isRunning else {
        break
      }

      sleep(delay)
      response = try? client?.get(url: url).wait()
      count += 1
    } while count < polls && response == nil

    // end the process regardless of success
    process.terminate()

    if let response = response {
      XCTAssertTrue(response.status == .ok, "Response was not ok")

      guard let data = (response.body.flatMap { $0.getData(at: 0, length: $0.readableBytes) })
      else {
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
