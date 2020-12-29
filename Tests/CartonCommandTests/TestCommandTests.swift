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
//  Created by Cavelle Benjamin on Dec/25/20.
//

@testable import CartonCLI
import TSCBasic
import XCTest

extension TestCommandTests: Testable {}

final class TestCommandTests: XCTestCase {
  func testWithNoArguments() throws {
    // given I've created a directory
    let package = "TestApp"
    let packageDirectory = testFixturesDirectory.appending(components: "carton-test", package)

    // let bundle = "Bundle"
    // let bundleDirectory = packageDirectory.appending(component: bundle)

    // it's ok if there is nothing to delete
    // do { try bundleDirectory.delete() } catch {}

    XCTAssertTrue(packageDirectory.exists, "The carton-test/TestApp directory does not exist")

    AssertExecuteCommand(
      command: "carton test",
      cwd: packageDirectory.url,
      debug: true
    )

    // // Confirm that the files are actually in the folder
    // XCTAssertTrue(bundleDirectory.exists, "The Bundle directory should exist")
    // XCTAssertTrue(bundleDirectory.ls().contains("index.html"), "Bundle does not have index.html")
    // XCTAssertFalse(
    //   (bundleDirectory.ls().filter { $0.contains("wasm") }).isEmpty,
    //   ".wasm file does not exist"
    // )
    // XCTAssertFalse(
    //   (bundleDirectory.ls().filter { $0.contains("js") }).isEmpty,
    //   ".js does not exist"
    // )

    // // finally, clean up
    let buildDirectory = packageDirectory.appending(component: ".build")
    do { try buildDirectory.delete() } catch {}
  }
}
