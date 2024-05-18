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

import CartonHelpers
import XCTest

@testable import CartonCLI

private enum Constants {
  static let testAppPackageName = "TestApp"
  static let nodeJSKitPackageName = "NodeJSKitTest"
  static let crashTestPackageName = "CrashTest"
  static let failTestPackageName = "FailTest"
}

func skipBrowserTest() throws {
  throw XCTSkip("[FIXME] Running tests in the browser is currently disabled because it causes freezing")
}

final class TestCommandTests: XCTestCase {
  func testWithNoArguments() throws {
    try withFixture(Constants.testAppPackageName) { packageDirectory in
      let result = try swiftRun(
        ["carton", "test"], packageDirectory: packageDirectory.url
      )
      result.assertZeroExit()
    }
  }

  func testEnvironmentNodeNoJSKit() throws {
    try withFixture(Constants.testAppPackageName) { packageDirectory in
      let result = try swiftRun(
        ["carton", "test", "--environment", "node"], packageDirectory: packageDirectory.url
      )
      result.assertZeroExit()
    }
  }

  func testEnvironmentNodeJSKit() throws {
    try withFixture(Constants.nodeJSKitPackageName) { packageDirectory in
      let result = try swiftRun(
        ["carton", "test", "--environment", "node"], packageDirectory: packageDirectory.url
      )
      result.assertZeroExit()
    }
  }

  func testSkipBuild() throws {
    try withFixture(Constants.nodeJSKitPackageName) { packageDirectory in
      var result = try swiftRun(
        ["carton", "test", "--environment", "node"], packageDirectory: packageDirectory.url
      )
      result.assertZeroExit()

      result = try swiftRun(
        [
          "carton", "test", "--environment", "node",
          "--prebuilt-test-bundle-path",
          "./.build/carton/wasm32-unknown-wasi/debug/NodeJSKitTestPackageTests.wasm",
        ],
        packageDirectory: packageDirectory.url
      )
      result.assertZeroExit()
    }
  }

  func testHeadlessBrowser() throws {
    try skipBrowserTest()
    guard Process.findExecutable("safaridriver") != nil else {
      throw XCTSkip("WebDriver is required")
    }
    try withFixture(Constants.testAppPackageName) { packageDirectory in
      let result = try swiftRun(
        ["carton", "test", "--environment", "browser", "--headless"],
        packageDirectory: packageDirectory.url
      )
      result.assertZeroExit()
    }
  }

  func testHeadlessBrowserWithCrash() throws {
    try skipBrowserTest()
    try checkCartonTestFail(fixture: Constants.crashTestPackageName)
  }

  func testHeadlessBrowserWithFail() throws {
    try skipBrowserTest()
    try checkCartonTestFail(fixture: Constants.failTestPackageName)
  }

  func checkCartonTestFail(fixture: String) throws {
    guard Process.findExecutable("safaridriver") != nil else {
      throw XCTSkip("WebDriver is required")
    }
    try withFixture(fixture) { packageDirectory in
      let result = try swiftRun(
        ["carton", "test", "--environment", "browser", "--headless"],
        packageDirectory: packageDirectory.url
      )
      XCTAssertNotEqual(result.exitCode, 0)
    }
  }

  // This test is prone to hanging on Linux.
  #if os(macOS)
    func testEnvironmentDefaultBrowser() throws {
      try skipBrowserTest()
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
        let result = try swiftRun(
          ["carton", "test", "--environment", "browser", "--port", "8082"],
          packageDirectory: packageDirectory.url
        )
        XCTAssertTrue(result.stdout.contains(expectedContent))
      }
    }
  #endif
}

enum ControlCode {
  static let ESC = "\u{001B}"
  static let CSI = "\(ESC)["
}
