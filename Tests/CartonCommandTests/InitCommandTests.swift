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

import TSCBasic
import XCTest

@testable import CartonCLI

final class InitCommandTests: XCTestCase {
  func testWithNoArguments() throws {
    try withTemporaryDirectory { tmpDirPath in
      let package = "wasp"
      let packageDirectory = tmpDirPath.appending(component: package)

      try packageDirectory.mkdir()
      try ProcessEnv.chdir(packageDirectory)
      try Process.checkNonZeroExit(arguments: [cartonPath, "init"])

      // Confirm that the files are actually in the folder
      XCTAssertTrue(packageDirectory.ls().contains("Package.swift"), "Package.swift does not exist")
      XCTAssertTrue(packageDirectory.ls().contains(".gitignore"), ".gitignore does not exist")
      XCTAssertTrue(packageDirectory.ls().contains("Sources"), "Sources does not exist")
      XCTAssertTrue(
        packageDirectory.ls().contains("Sources/\(package)"),
        "Sources/\(package) does not exist"
      )
      XCTAssertTrue(
        packageDirectory.ls().contains("Sources/\(package)/main.swift"),
        "Sources/\(package)/main.swift does not exist"
      )
      XCTAssertTrue(packageDirectory.ls().contains("Tests"), "Tests does not exist")
      XCTAssertTrue(
        packageDirectory.ls().contains("Tests/\(package)LibraryTests"),
        "Tests/\(package)LibraryTests does not exist"
      )
      XCTAssertTrue(
        packageDirectory.ls().contains("Tests/\(package)LibraryTests/\(package)LibraryTests.swift"),
        "Tests/\(package)LibraryTests/\(package)LibraryTests.swift does not exist"
      )
    }
  }

  func testInitWithTokamakTemplate() throws {
    try withTemporaryDirectory { tmpDirPath in

      let package = "fusion"
      let packageDirectory = tmpDirPath.appending(component: package)

      try packageDirectory.mkdir()
      try ProcessEnv.chdir(packageDirectory)
      try Process.checkNonZeroExit(arguments: [cartonPath, "init", "--template", "tokamak"])

      // Confirm that the files are actually in the folder
      XCTAssertTrue(packageDirectory.ls().contains("Package.swift"), "Package.swift does not exist")
      XCTAssertTrue(packageDirectory.ls().contains(".gitignore"), ".gitignore does not exist")
      XCTAssertTrue(packageDirectory.ls().contains("Sources"), "Sources does not exist")
      XCTAssertTrue(
        packageDirectory.ls().contains("Sources/\(package)"),
        "Sources/\(package) does not exist"
      )
      XCTAssertTrue(
        packageDirectory.ls().contains("Sources/\(package)/App.swift"),
        "Sources/\(package)/App.swift does not exist"
      )
      XCTAssertTrue(packageDirectory.ls().contains("Tests"), "Tests does not exist")
      XCTAssertTrue(
        packageDirectory.ls().contains("Tests/\(package)LibraryTests"),
        "Tests/\(package)LibraryTests does not exist"
      )
      XCTAssertTrue(
        packageDirectory.ls().contains("Tests/\(package)LibraryTests/\(package)LibraryTests.swift"),
        "Tests/\(package)LibraryTests/\(package)LibraryTests.swift does not exist"
      )
    }
  }
}
