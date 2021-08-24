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
  func testWithNoArguments() throws {
    // given I've created a directory
    let package = "wasp"
    let packageDirectory = testFixturesDirectory.appending(component: package)

    // it's ok if there is nothing to delete
    do { try packageDirectory.delete() } catch {}

    try packageDirectory.mkdir()

    XCTAssertTrue(packageDirectory.exists, "Did not create \(package) directory")

    AssertExecuteCommand(
      command: "carton init",
      cwd: packageDirectory.url
    )

    // Confirm that the files are actually in the folder
    XCTAssertTrue(packageDirectory.ls().contains("Package.swift"), "Package.swift does not exist")
    XCTAssertTrue(packageDirectory.ls().contains("README.md"), "README.md does not exist")
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
      packageDirectory.ls().contains("Tests/\(package)Tests"),
      "Tests/\(package)Tests does not exist"
    )
    XCTAssertTrue(
      packageDirectory.ls().contains("Tests/\(package)Tests/\(package)Tests.swift"),
      "Tests/\(package)Tests/\(package)Tests.swift does not exist"
    )
    XCTAssertTrue(
      packageDirectory.ls().contains("Tests/\(package)Tests/XCTestManifests.swift"),
      "Tests/\(package)Tests/XCTestManifests.swift does not exist"
    )

    // finally, clean up
    try packageDirectory.delete()
  }

  func testInitWithTokamakTemplate() throws {
    // given I've created a directory
    let package = "fusion"
    let packageDirectory = testFixturesDirectory.appending(component: package)

    // it's ok if there is nothing to delete
    do { try packageDirectory.delete() } catch {}

    try packageDirectory.mkdir()

    XCTAssertTrue(packageDirectory.exists, "Did not create \(package) directory")

    AssertExecuteCommand(
      command: "carton init --template tokamak",
      cwd: packageDirectory.url
    )

    // Confirm that the files are actually in the folder
    XCTAssertTrue(packageDirectory.ls().contains("Package.swift"), "Package.swift does not exist")
    XCTAssertTrue(packageDirectory.ls().contains("README.md"), "README.md does not exist")
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
      packageDirectory.ls().contains("Tests/\(package)Tests"),
      "Tests/\(package)Tests does not exist"
    )
    XCTAssertTrue(
      packageDirectory.ls().contains("Tests/\(package)Tests/\(package)Tests.swift"),
      "Tests/\(package)Tests/\(package)Tests.swift does not exist"
    )
    XCTAssertTrue(
      packageDirectory.ls().contains("Tests/\(package)Tests/XCTestManifests.swift"),
      "Tests/\(package)Tests/XCTestManifests.swift does not exist"
    )

    let actualTemplateSource = try String(contentsOfFile: packageDirectory
      .appending(components: "Sources", package, "main.swift").pathString)

    XCTAssertEqual(expectedTemplateSource, actualTemplateSource, "Template Sources do not match")

    // finally, clean up
    try packageDirectory.delete()
  }

  let expectedTemplateSource =
    """
    import TokamakDOM

    struct TokamakApp: App {
        var body: some Scene {
            WindowGroup("Tokamak App") {
                ContentView()
            }
        }
    }

    struct ContentView: View {
        var body: some View {
            Text("Hello, world!")
        }
    }

    // @main attribute is not supported in SwiftPM apps.
    // See https://bugs.swift.org/browse/SR-12683 for more details.
    TokamakApp.main()

    """
}
