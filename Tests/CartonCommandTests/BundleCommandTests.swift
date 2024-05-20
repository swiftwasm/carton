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

@testable import CartonFrontend

final class BundleCommandTests: XCTestCase {
  func testWithNoArguments() async throws {
    try await withFixture("EchoExecutable") { packageDirectory in
      let bundleDirectory = packageDirectory.appending(component: "Bundle")

      let result = try await swiftRun(["carton", "bundle"], packageDirectory: packageDirectory.url)
      try result.checkNonZeroExit()

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

  func testWithDebugInfo() async throws {
    try await withFixture("EchoExecutable") { packageDirectory in
      let result = try await swiftRun(
        ["carton", "bundle", "--debug-info"], packageDirectory: packageDirectory.url
      )
      try result.checkNonZeroExit()

      let bundleDirectory = packageDirectory.appending(component: "Bundle")
      guard let wasmBinary = (bundleDirectory.ls().filter { $0.contains("wasm") }).first else {
        XCTFail("No wasm binary found")
        return
      }
      let headers = try await Process.checkNonZeroExit(arguments: [
        "wasm-objdump", "--headers", bundleDirectory.appending(component: wasmBinary).pathString,
      ])
      XCTAssert(headers.contains("\"name\""), "name section not found: \(headers)")
    }
  }

  func testWithoutContentHash() async throws {
    try await withFixture("EchoExecutable") { packageDirectory in
      let result = try await swiftRun(
        ["carton", "bundle", "--no-content-hash", "--wasm-optimizations", "none"], packageDirectory: packageDirectory.url
      )
      try result.checkNonZeroExit()

      let bundleDirectory = packageDirectory.appending(component: "Bundle")
      guard let wasmBinary = (bundleDirectory.ls().filter { $0.contains("wasm") }).first else {
        XCTFail("No wasm binary found")
        return
      }
      XCTAssertEqual(wasmBinary, "my-echo.wasm")
    }
  }

  func testWasmOptimizationOptions() async throws {
    try await withFixture("EchoExecutable") { packageDirectory in
      func getFileSizeOfWasmBinary(wasmOptimizations: WasmOptimizations) async throws -> UInt64 {
        let bundleDirectory = packageDirectory.appending(component: "Bundle")

        let result = try await swiftRun(
          ["carton", "bundle", "--wasm-optimizations", wasmOptimizations.rawValue],
          packageDirectory: packageDirectory.url
        )
        try result.checkNonZeroExit()

        guard let wasmFile = (bundleDirectory.ls().filter { $0.contains("wasm") }).first else {
          XCTFail("No wasm binary found")
          return 0
        }

        return try localFileSystem.getFileInfo(bundleDirectory.appending(component: wasmFile)).size
      }

      let none = try await getFileSizeOfWasmBinary(wasmOptimizations: .none)
      let optimized = try await getFileSizeOfWasmBinary(wasmOptimizations: .size)
      XCTAssertGreaterThan(none, optimized)
    }
  }
}
