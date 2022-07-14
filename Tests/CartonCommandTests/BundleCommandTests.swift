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

final class BundleCommandTests: XCTestCase {
  func testWithNoArguments() throws {
    try withFixture("EchoExecutable") { packageDirectory in
      let bundleDirectory = packageDirectory.appending(component: "Bundle")

      AssertExecuteCommand(command: "carton bundle", cwd: packageDirectory.url)

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

  func testWithXswiftc() throws {
    try withFixture("EchoExecutable") { packageDirectory in
      AssertExecuteCommand(
        command: "carton bundle -Xswiftc --fake-swiftc-options",
        cwd: packageDirectory.url,
        expected: "error: unknown argument: '--fake-swiftc-options'",
        expectedContains: true
      )
    }
  }

  func testWithDebugInfo() throws {
    try withTemporaryDirectory { tmpDirPath in
      try ProcessEnv.chdir(tmpDirPath)
      try Process.checkNonZeroExit(arguments: [cartonPath, "init", "--template", "basic"])
      try Process.checkNonZeroExit(arguments: [cartonPath, "bundle", "--debug-info"])

      let bundleDirectory = tmpDirPath.appending(component: "Bundle")
      guard let wasmBinary = (bundleDirectory.ls().filter { $0.contains("wasm") }).first else {
        XCTFail("No wasm binary found")
        return
      }
      let headers = try Process.checkNonZeroExit(arguments: [
        "wasm-objdump", "--headers", bundleDirectory.appending(component: wasmBinary).pathString
      ])
      XCTAssert(headers.contains("\"name\""), "name section not found: \(headers)")
    }
  }

  func testWasmOptimizationOptions() throws {
    try withTemporaryDirectory { tmpDirPath in
      try ProcessEnv.chdir(tmpDirPath)
      try Process.checkNonZeroExit(arguments: [cartonPath, "init", "--template", "basic"])

      func getFileSizeOfWasmBinary(wasmOptimizations: WasmOptimizations) throws -> UInt64 {
        let bundleDirectory = tmpDirPath.appending(component: "Bundle")

        try Process.checkNonZeroExit(arguments: [cartonPath, "bundle", "--wasm-optimizations", wasmOptimizations.rawValue])

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
