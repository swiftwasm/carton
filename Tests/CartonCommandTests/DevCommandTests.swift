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

extension DevCommandTests: Testable {}

final class DevCommandTests: XCTestCase {
  var client: HTTPClient?

  override func tearDown() {
    print("shutting down client")
    try? client?.syncShutdown()
    client = nil
  }

  func testWithNoArguments() throws {
    let url = "http://localhost:8080"

    // 20 seconds seems to be the right amount of time.
    let waitTime: Int64 = 60

    // the directory was built using `carton init --template tokamak`
    let package = "Milk"
    let packageDirectory = testFixturesDirectory.appending(component: package)
    XCTAssertTrue(
      packageDirectory.exists,
      "\(package) directory does not exist. Cannot execute tests."
    )

    do { try packageDirectory.appending(component: ".build").delete() } catch {}

    let expectedHtml =
      """
      <html>
        <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <script type="text/javascript" src="dev.js"></script>
        </head>
        <body>
        </body>
      </html>
      """

    guard let process = executeCommand(
      command: "carton dev",
      cwd: packageDirectory.url,
      debug: true
    ) else {
      XCTFail("Could not create process")
      return
    }

    let timeout = HTTPClient.Configuration.Timeout(
      connect: .seconds(waitTime),
      read: .seconds(waitTime)
    )
    client = HTTPClient(eventLoopGroupProvider: .createNew,
                        configuration: HTTPClient.Configuration(timeout: timeout))

    // block until we get a response or fail
    guard let response = try? client?.get(url: url).wait() else {
      XCTFail("Could not reach host at \(url)")
      return
    }

    process.terminate()

    XCTAssertTrue(response.status == .ok, "Response was not ok")
    guard let data = (response.body.flatMap { $0.getData(at: 0, length: $0.readableBytes) }) else {
      XCTFail("Could not map data")
      return
    }
    guard let actualHtml = String(data: data, encoding: .utf8) else {
      XCTFail("Could convert data to string")
      return
    }

    // test may be brittle as the template may change over time.
    XCTAssertEqual(actualHtml, expectedHtml, "HTML output does not match")

    // clean up
    do { try packageDirectory.appending(component: ".build").delete() } catch {}
  }
}
