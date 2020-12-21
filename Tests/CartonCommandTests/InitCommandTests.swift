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
import TSCBasic
import XCTest

extension InitCommandTests: Testable {}

final class InitCommandTests: XCTestCase {
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
      OVERVIEW: Create a Swift package for a new SwiftWasm project.

      USAGE: carton init [--template <template>] [--name <name>] <subcommand>

      OPTIONS:
        --template <template>   The template to base the project on.
        --name <name>           The name of the project
        --version               Show the version.
        -h, --help              Show help information.

      SUBCOMMANDS:
        list-templates          List the available templates

        See 'carton help init <subcommand>' for detailed help.
      """
    // when
    // then

    AssertExecuteCommand(command: "carton init -h", expected: expectation)
  }

  func testWithNoArguments() throws {
    // given I've created a directory
    let package = "wasp"
    let packageDirectory = testFixturesDirectory.appending(component: package)

    // it's ok if there is nothing to delete
    do { try packageDirectory.delete() } catch {}

    try packageDirectory.mkdir()

    // then I expect a default template to be created
    let expectation =
      """
      Creating new project with template basic in \(package)
      - checking Swift compiler path: \(AbsolutePath
        .home)/.carton/sdk/wasm-5.3.1-RELEASE/usr/bin/swift
      - checking Swift compiler path: \(AbsolutePath
        .home)/.swiftenv/versions/wasm-5.3.1-RELEASE/usr/bin/swift
      - checking Swift compiler path: \(AbsolutePath
        .home)/Library/Developer/Toolchains/swift-wasm-5.3.1-RELEASE.xctoolchain/usr/bin/swift
      Inferring basic settings...
      - swift executable: \(AbsolutePath
        .home)/Library/Developer/Toolchains/swift-wasm-5.3.1-RELEASE.xctoolchain/usr/bin/swift
      SwiftWasm Swift version 5.3 (swiftlang-5.3.1)
      Target: x86_64-apple-darwin20.2.0

      Parsing package manifest: \(AbsolutePath
        .home)/Library/Developer/Toolchains/swift-wasm-5.3.1-RELEASE.xctoolchain/usr/bin/swift package dump-package

      Running...
      \(AbsolutePath
        .home)/Library/Developer/Toolchains/swift-wasm-5.3.1-RELEASE.xctoolchain/usr/bin/swift package init --type executable
      Creating executable package: \(package)
      Creating Package.swift
      Creating README.md
      Creating .gitignore
      Creating Sources/
      Creating Sources/\(package)/main.swift
      Creating Tests/
      Creating Tests/LinuxMain.swift
      Creating Tests/\(package)Tests/
      Creating Tests/\(package)Tests/\(package)Tests.swift
      Creating Tests/\(package)Tests/XCTestManifests.swift


      `swift` process finished successfully
      """

    // when run cartin init with no additional parameters
    AssertExecuteCommand(
      command: "carton init",
      cwd: packageDirectory.url,
      expected: expectation
    )

    // Confirm that the files are actually in the folder
    XCTAssertTrue(packageDirectory.ls().contains("Package.swift"))
    XCTAssertTrue(packageDirectory.ls().contains("README.md"))
    XCTAssertTrue(packageDirectory.ls().contains(".gitignore"))
    XCTAssertTrue(packageDirectory.ls().contains("Sources"))
    XCTAssertTrue(packageDirectory.ls().contains("Sources/\(package)"))
    XCTAssertTrue(packageDirectory.ls().contains("Sources/\(package)/main.swift"))
    XCTAssertTrue(packageDirectory.ls().contains("Tests"))
    XCTAssertTrue(packageDirectory.ls().contains("Tests/LinuxMain.swift"))
    XCTAssertTrue(packageDirectory.ls().contains("Tests/\(package)Tests"))
    XCTAssertTrue(packageDirectory.ls().contains("Tests/\(package)Tests/\(package)Tests.swift"))
    XCTAssertTrue(packageDirectory.ls().contains("Tests/\(package)Tests/XCTestManifests.swift"))

    // finally, clean up
    try packageDirectory.delete()
  }
}
