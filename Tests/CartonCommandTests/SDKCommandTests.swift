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

extension SDKCommandTests: Testable {}

final class SDKCommandTests: XCTestCase {
  func testInstall() throws {
    AssertExecuteCommand(
      command: "carton sdk install",
      cwd: packageDirectory.url,
      expected: "SDK successfully installed!",
      expectedContains: true
    )
  }

  func testVersions() throws {
    AssertExecuteCommand(
      command: "carton sdk versions",
      cwd: packageDirectory.url,
      expected: "wasm-",
      expectedContains: true
    )
  }

  func testLocalNoFile() throws {
    let package = "Milk"
    let packageDirectory = testFixturesDirectory.appending(component: package)
    let swiftVersion = packageDirectory.appending(component: ".swift-version")

    let versionInfo: String? = try? String(contentsOf: swiftVersion.url)

    // it's ok if there is nothing to delete
    do { try swiftVersion.delete() } catch {}

    AssertExecuteCommand(
      command: "carton sdk local",
      cwd: packageDirectory.url,
      expected: "Version file is not present: ",
      expectedContains: true
    )

    if let info = versionInfo {
      try info.write(to: swiftVersion.url, atomically: true, encoding: .utf8)
    }
  }

  func testLocalWithFile() throws {
    let package = "Milk"
    let packageDirectory = testFixturesDirectory.appending(component: package)
    let swiftVersion = packageDirectory.appending(component: ".swift-version")

    let versionInfo: String? = try? String(contentsOf: swiftVersion.url)

    // it's ok if there is nothing to delete
    do { try swiftVersion.delete() } catch {}

    let alternateLocal = "wasm-5.4.0"

    try alternateLocal.write(to: swiftVersion.url, atomically: true, encoding: .utf8)

    AssertExecuteCommand(
      command: "carton sdk local",
      cwd: packageDirectory.url,
      expected: "wasm-5.4.0",
      expectedContains: true
    )

    // remove the fixture we created and write the original back if there was one
    do { try swiftVersion.delete() } catch {}
    if let info = versionInfo {
      try info.write(to: swiftVersion.url, atomically: true, encoding: .utf8)
    }
  }
}
