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

@testable import CartonCLI
import XCTest

extension DevCommandTests: Testable {}

final class DevCommandTests: XCTestCase {
  override static func setUp() {
    // ensure the SDK is installed first
    AssertExecuteCommand(command: "carton sdk install")
  }

  func testDefaultArgumentParsing() throws {
    // given
    let arguments: [String] = []

    // when

    AssertParse(Dev.self, arguments) { command in
      // then
      XCTAssertNotNil(command)
    }
  }

  func testHelpString() throws {
    // given
    let expectation =
      """
      OVERVIEW: Watch the current directory, host the app, rebuild on change.

      USAGE: carton dev [--product <product>] [--destination <destination>] [--custom-index-page <custom-index-page>] [--release] [--verbose] [--port <port>] [--skip-auto-open]

      OPTIONS:
        --product <product>     Specify name of an executable product in development.
        --destination <destination>
                                This option has no effect and will be removed in a
                                future version of `carton`
        --custom-index-page <custom-index-page>
                                Specify a path to a custom `index.html` file to be
                                used for your app.
        --release               When specified, build in the release mode.
        -v, --verbose           Don't clear terminal window after files change.
        -p, --port <port>       Set the HTTP port the development server will run on.
                                (default: 8080)
        --skip-auto-open        Skip automatically opening app in system browser.
        --version               Show the version.
        -h, --help              Show help information.
      """
    // when
    // then

    AssertExecuteCommand(command: "carton dev -h", expected: expectation)
  }
}
