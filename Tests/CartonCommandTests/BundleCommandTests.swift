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
import CartonCore
import XCTest

final class BundleCommandTests: XCTestCase {
  func testWithNoArguments() async throws {
    let fs = localFileSystem

    try await withFixture("EchoExecutable") { packageDirectory in
      let bundleDirectory = packageDirectory.appending(component: "Bundle")

      let result = try await swiftRun(["carton", "bundle"], packageDirectory: packageDirectory.asURL)
      try result.checkNonZeroExit()

      // Confirm that the files are actually in the folder
      XCTAssertTrue(fs.isDirectory(bundleDirectory), "The bundle directory should exist")

      let files = try fs.getDirectoryContents(bundleDirectory)

      XCTAssertTrue(
        files.contains { $0 == "index.html" },
        "The bundle should include an index.html file, but it was not found"
      )

      XCTAssertTrue(
        files.contains { $0.pathExtension == "wasm" },
        "The bundle should include a .wasm files, but it was not found"
      )

      XCTAssertTrue(
        files.contains { $0.pathExtension == "js" },
        "The bundle should include a .js files, but it was not found"
      )
    }
  }

  func testWithDebugInfo() async throws {
    try await withFixture("EchoExecutable") { packageDirectory in
      let result = try await swiftRun(
        ["carton", "bundle", "--debug-info"], packageDirectory: packageDirectory.asURL
      )
      try result.checkNonZeroExit()

      let bundleDirectory = packageDirectory.appending(component: "Bundle")

      guard let wasmBinary = try FileManager.default.contentsOfDirectory(atPath: bundleDirectory.pathString)
        .filter({ $0.pathExtension == "wasm" }).first else
      {
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
    let fs = localFileSystem

    try await withFixture("EchoExecutable") { packageDirectory in
      let result = try await swiftRun(
        ["carton", "bundle", "--no-content-hash", "--wasm-optimizations", "none"], 
        packageDirectory: packageDirectory.asURL
      )
      try result.checkNonZeroExit()

      let bundleDirectory = packageDirectory.appending(component: "Bundle")
      guard let wasmBinary = try fs.getDirectoryContents(bundleDirectory)
        .filter({ $0.pathExtension == "wasm" }).first else
      {
        XCTFail("No wasm binary found")
        return
      }
      XCTAssertEqual(wasmBinary, "my-echo.wasm")
    }
  }

  func testWasmOptimizationOptions() async throws {
    let fs = localFileSystem

    try await withFixture("EchoExecutable") { packageDirectory in
      func getFileSizeOfWasmBinary(wasmOptimizations: String) async throws -> UInt64 {
        let bundleDirectory = packageDirectory.appending(component: "Bundle")

        let result = try await swiftRun(
          ["carton", "bundle", "--wasm-optimizations", wasmOptimizations],
          packageDirectory: packageDirectory.asURL
        )
        try result.checkNonZeroExit()

        guard let wasmFile = try fs.getDirectoryContents(bundleDirectory)
          .filter({ $0.pathExtension == "wasm" }).first else
        {
          XCTFail("No wasm binary found")
          return 0
        }

        return try localFileSystem.getFileInfo(
          bundleDirectory.appending(component: wasmFile)
        ).size
      }

      let none = try await getFileSizeOfWasmBinary(wasmOptimizations: "none")
      let optimized = try await getFileSizeOfWasmBinary(wasmOptimizations: "size")
      XCTAssertGreaterThan(none, optimized)
    }
  }

  func testExtraOptions() async throws {
    try await withFixture("EchoExecutable") { packageDirectory in
      let result = try await swiftRun(
        ["carton", "bundle", "-Xwasm-opt=--enable-threads"],
        packageDirectory: packageDirectory.asURL
      )
      try result.checkNonZeroExit()
      let output = try result.utf8Output()
      let hasExpectedLine = output.split(whereSeparator: \.isNewline).contains {
          $0.contains(#/wasm-opt (.+ )?--enable-threads/#)
      }
      XCTAssert(hasExpectedLine, "wasm-opt invocation log with extra options not found in output: \(output)")
    }
  }
}

fileprivate extension String {
  var pathExtension: String {
    self.split(separator: ".").last.map(String.init) ?? ""
  }
}
