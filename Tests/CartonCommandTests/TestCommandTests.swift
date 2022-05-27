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
//  Created by Cavelle Benjamin on Dec/28/20.
//

import AsyncHTTPClient
import TSCBasic
import XCTest

@testable import CartonCLI

private enum Constants {
  static let testAppPackageName = "TestApp"
  static let nodeJSKitPackageName = "NodeJSKitTest"
}

final class TestCommandTests: XCTestCase {

  func testWithNoArguments() throws {
    try withFixture(Constants.testAppPackageName) { packageDirectory in
      AssertExecuteCommand(
        command: "carton test",
        cwd: packageDirectory.url,
        debug: true
      )
    }
  }

  func testEnvironmentNodeNoJSKit() throws {
    try withFixture(Constants.testAppPackageName) { packageDirectory in
      AssertExecuteCommand(
        command: "carton test --environment node",
        cwd: packageDirectory.url,
        debug: true
      )
    }
  }

  func testEnvironmentNodeJSKit() throws {
    try withFixture(Constants.nodeJSKitPackageName) { packageDirectory in
      AssertExecuteCommand(
        command: "carton test --environment node",
        cwd: packageDirectory.url,
        debug: true
      )
    }
  }

  // This test is prone to hanging on Linux.
  #if os(macOS)
  func testEnvironmentDefaultBrowser() throws {
    try withFixture(Constants.testAppPackageName) { packageDirectory in
      let expectedTestSuiteCount = 1
      let expectedTestsCount = 1

      let expectedContent =
        """
        Test Suites: \(ControlCode.CSI)32m\(expectedTestSuiteCount) passed\(ControlCode
          .CSI)0m, \(expectedTestSuiteCount) total
        Tests:       \(ControlCode.CSI)32m\(expectedTestsCount) passed\(ControlCode
          .CSI)0m, \(expectedTestsCount) total
        """

      // FIXME: Don't assume a specific port is available since it can be used by others or tests
      AssertExecuteCommand(
        command: "carton test --environment defaultBrowser --port 8082",
        cwd: packageDirectory.url,
        expected: expectedContent,
        expectedContains: true
      )
    }
  }
  #endif
}

enum ControlCode {
  static let ESC = "\u{001B}"
  static let CSI = "\(ESC)["
}
