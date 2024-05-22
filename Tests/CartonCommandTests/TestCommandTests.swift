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

@testable import CartonFrontend

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
  func testWithNoArguments() async throws {
    try await withFixture(Constants.testAppPackageName) { packageDirectory in
      let result = try await swiftRun(
        ["carton", "test"], packageDirectory: packageDirectory.asURL
      )
      try result.checkNonZeroExit()
    }
  }

  func testEnvironmentNodeNoJSKit() async throws {
    try await withFixture(Constants.testAppPackageName) { packageDirectory in
      let result = try await swiftRun(
        ["carton", "test", "--environment", "node"], packageDirectory: packageDirectory.asURL
      )
      try result.checkNonZeroExit()
    }
  }

  func testEnvironmentNodeJSKit() async throws {
    try await withFixture(Constants.nodeJSKitPackageName) { packageDirectory in
      let result = try await swiftRun(
        ["carton", "test", "--environment", "node"], packageDirectory: packageDirectory.asURL
      )
      try result.checkNonZeroExit()
    }
  }

  func testSkipBuild() async throws {
    try await withFixture(Constants.nodeJSKitPackageName) { packageDirectory in
      var result = try await swiftRun(
        ["carton", "test", "--environment", "node"], packageDirectory: packageDirectory.asURL
      )
      try result.checkNonZeroExit()

      result = try await swiftRun(
        [
          "carton", "test", "--environment", "node",
          "--prebuilt-test-bundle-path",
          "./.build/carton/wasm32-unknown-wasi/debug/NodeJSKitTestPackageTests.wasm",
        ],
        packageDirectory: packageDirectory.asURL
      )
      try result.checkNonZeroExit()
    }
  }

  func testHeadlessBrowser() async throws {
    try skipBrowserTest()
    guard Process.findExecutable("safaridriver") != nil else {
      throw XCTSkip("WebDriver is required")
    }
    try await withFixture(Constants.testAppPackageName) { packageDirectory in
      let result = try await swiftRun(
        ["carton", "test", "--environment", "browser", "--headless"],
        packageDirectory: packageDirectory.asURL
      )
      try result.checkNonZeroExit()
    }
  }

  func testHeadlessBrowserWithCrash() async throws {
    try skipBrowserTest()
    try await checkCartonTestFail(fixture: Constants.crashTestPackageName)
  }

  func testHeadlessBrowserWithFail() async throws {
    try skipBrowserTest()
    try await checkCartonTestFail(fixture: Constants.failTestPackageName)
  }

  func checkCartonTestFail(fixture: String) async throws {
    guard Process.findExecutable("safaridriver") != nil else {
      throw XCTSkip("WebDriver is required")
    }
    try await withFixture(fixture) { packageDirectory in
      let result = try await swiftRun(
        ["carton", "test", "--environment", "browser", "--headless"],
        packageDirectory: packageDirectory.asURL
      )
      try result.checkNonZeroExit()
    }
  }

  // This test is prone to hanging on Linux.
  #if os(macOS)
    func testEnvironmentDefaultBrowser() async throws {
      try skipBrowserTest()
      try await withFixture(Constants.testAppPackageName) { packageDirectory in
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
        let result = try await swiftRun(
          ["carton", "test", "--environment", "browser", "--port", "8082"],
          packageDirectory: packageDirectory.asURL
        )
        try result.checkNonZeroExit()
        let output = try result.utf8Output()
        XCTAssertTrue(output.contains(expectedContent))
      }
    }
  #endif
}

enum ControlCode {
  static let ESC = "\u{001B}"
  static let CSI = "\(ESC)["
}
