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

extension TestCommandTests: Testable {}

private enum Constants {
  static let anyPackageName = "TestApp"
}

final class TestCommandTests: XCTestCase {
  private var client: HTTPClient?

  override func tearDown() {
    try? client?.syncShutdown()
    client = nil
  }

  func testWithNoArguments() throws {
    let packageDirectory = givenAPackageTestDirectory(Constants.anyPackageName)

    AssertExecuteCommand(
      command: "carton test",
      cwd: packageDirectory.url,
      debug: true
    )
  }

  func testEnvironmentNode() throws {
    let packageDirectory = givenAPackageTestDirectory(Constants.anyPackageName)

    AssertExecuteCommand(
      command: "carton test --environment node",
      cwd: packageDirectory.url,
      debug: true
    )
  }

  // This test is prone to hanging on Linux.
  #if os(macOS)
    func testEnvironmentDefaultBrowser() throws {
      let packageDirectory = givenAPackageTestDirectory()

      let expectedTestSuiteCount = 1
      let expectedTestsCount = 1

      let expectedContent =
        """
        Test Suites: \(ControlCode.CSI)32m\(expectedTestSuiteCount) passed\(ControlCode
        .CSI)0m, \(expectedTestSuiteCount) total
        Tests:       \(ControlCode.CSI)32m\(expectedTestsCount) passed\(ControlCode
        .CSI)0m, \(expectedTestsCount) total
        """

      AssertExecuteCommand(
        command: "carton test --environment defaultBrowser",
        cwd: packageDirectory.url,
        expected: expectedContent,
        expectedContains: true
      )
    }
  #endif

  private func givenAPackageTestDirectory(_ name: String = Constants.anyPackageName)
    -> TestDirectory
  {
    let packageDirectory = TestDirectory(testFixturesDirectory, name)

    XCTAssertTrue(packageDirectory.exists, "The TestApp directory does not exist")

    return packageDirectory
  }

}

private class TestDirectory {
  private var directory: AbsolutePath

  var url: URL { directory.url }
  var exists: Bool { directory.exists }

  init(_ testDirectory: AbsolutePath, _ dirName: String) {
    self.directory = testDirectory.appending(components: dirName)
    cleanBuildDir()
  }

  deinit {
    cleanBuildDir()
  }

  private func cleanBuildDir() {
    // Clean up once this object is not needed anymore
    try? directory.appending(component: ".build").delete()
  }
}

enum ControlCode {
  static let ESC = "\u{001B}"
  static let CSI = "\(ESC)["
}
