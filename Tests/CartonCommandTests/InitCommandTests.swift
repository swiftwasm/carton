//
//  File.swift
//
//
//  Created by Cavelle Benjamin on Dec/21/20.
//

@testable import CartonCLI
import Path
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
    let packageDirectory = testFixturesDirectory.join(package)
    try packageDirectory.delete()
    try packageDirectory.mkdir()

    // then I expect a default template to be created
    let expectation =
      """
      Creating new project with template basic in \(package)
      - checking Swift compiler path: \(Path.home)/.carton/sdk/wasm-5.3.1-RELEASE/usr/bin/swift
      - checking Swift compiler path: \(Path
        .home)/.swiftenv/versions/wasm-5.3.1-RELEASE/usr/bin/swift
      - checking Swift compiler path: \(Path
        .home)/Library/Developer/Toolchains/swift-wasm-5.3.1-RELEASE.xctoolchain/usr/bin/swift
      Inferring basic settings...
      - swift executable: \(Path
        .home)/Library/Developer/Toolchains/swift-wasm-5.3.1-RELEASE.xctoolchain/usr/bin/swift
      SwiftWasm Swift version 5.3 (swiftlang-5.3.1)
      Target: x86_64-apple-darwin20.2.0

      Parsing package manifest: \(Path
        .home)/Library/Developer/Toolchains/swift-wasm-5.3.1-RELEASE.xctoolchain/usr/bin/swift package dump-package

      Running...
      \(Path
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
    AssertExecuteCommand(command: "carton init", cwd: packageDirectory.url, expected: expectation)

    // finally, clean up
    try packageDirectory.delete()
  }
}
