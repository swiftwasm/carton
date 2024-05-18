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

import CartonHelpers
import XCTest

@testable import CartonCLI

final class BundleCommandTests: XCTestCase {
  override func setUp() {
    setbuf(stdout, nil)
  }

  func testWithNoArguments() throws {
    try withFixture("EchoExecutable") { packageDirectory in
      let bundleDirectory = packageDirectory.appending(component: "Bundle")

      try swiftRun(["carton", "bundle"], packageDirectory: packageDirectory.url)

      // Confirm that the files are actually in the folder
      XCTAssertTrue(bundleDirectory.exists, "The Bundle directory should exist")
      XCTAssertTrue(bundleDirectory.ls().contains("index.html"), "Bundle does not have index.html")
      XCTAssertFalse(
        (bundleDirectory.ls().filter { $0.contains("wasm") }).isEmpty,
        ".wasm file does not exist"
      )
      XCTAssertFalse(
        (bundleDirectory.ls().filter { $0.contains("js") }).isEmpty,
        ".js does not exist"
      )
    }
  }

  func testWithDebugInfo() throws {
    trace()
    try withFixture("EchoExecutable") { packageDirectory in
      trace()
      let result = try swiftRun(
        ["carton", "bundle", "--debug-info"], packageDirectory: packageDirectory.url
      )
      trace()
      result.assertZeroExit()

      trace()
      let bundleDirectory = packageDirectory.appending(component: "Bundle")

      trace()
      guard let wasmBinary = (bundleDirectory.ls().filter { $0.contains("wasm") }).first else {
        trace()
        XCTFail("No wasm binary found")
        return
      }

      trace()
      let headers = try Process.checkNonZeroExit(arguments: [
        "wasm-objdump", "--headers", bundleDirectory.appending(component: wasmBinary).pathString,
      ])

      trace()
      XCTAssert(headers.contains("\"name\""), "name section not found: \(headers)")

      trace()
    }
    trace()
  }

  func testWithoutContentHash() throws {
    try withFixture("EchoExecutable") { packageDirectory in
      let result = try swiftRun(
        ["carton", "bundle", "--no-content-hash", "--wasm-optimizations", "none"], packageDirectory: packageDirectory.url
      )
      result.assertZeroExit()

      let bundleDirectory = packageDirectory.appending(component: "Bundle")
      guard let wasmBinary = (bundleDirectory.ls().filter { $0.contains("wasm") }).first else {
        XCTFail("No wasm binary found")
        return
      }
      XCTAssertEqual(wasmBinary, "my-echo.wasm")
    }
  }

  func testWasmOptimizationOptions() throws {
    try withFixture("EchoExecutable") { packageDirectory in
      func getFileSizeOfWasmBinary(wasmOptimizations: WasmOptimizations) throws -> UInt64 {
        let bundleDirectory = packageDirectory.appending(component: "Bundle")

        let result = try swiftRun(
          ["carton", "bundle", "--wasm-optimizations", wasmOptimizations.rawValue],
          packageDirectory: packageDirectory.url
        )
        result.assertZeroExit()

        guard let wasmFile = (bundleDirectory.ls().filter { $0.contains("wasm") }).first else {
          XCTFail("No wasm binary found")
          return 0
        }

        return try localFileSystem.getFileInfo(bundleDirectory.appending(component: wasmFile)).size
      }

      try XCTAssertGreaterThan(
        getFileSizeOfWasmBinary(wasmOptimizations: .none),
        getFileSizeOfWasmBinary(wasmOptimizations: .size)
      )
    }
  }
}
