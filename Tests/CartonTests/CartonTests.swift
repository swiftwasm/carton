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

import CartonHelpers
import CartonCore
import XCTest

import class Foundation.Bundle

@testable import SwiftToolchain

final class CartonTests: XCTestCase {
  /// Returns path to the built products directory.
  var productsDirectory: Foundation.URL {
    #if os(macOS)
      for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
        return bundle.bundleURL.deletingLastPathComponent()
      }
      fatalError("couldn't find the products directory")
    #else
      return Bundle.main.bundleURL
    #endif
  }

  func testVersion() throws {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.

    // Some of the APIs that we use below are available in macOS 10.13 and above.
    guard #available(macOS 10.13, *) else {
      return
    }

    let fooBinary = productsDirectory.appendingPathComponent("carton")

    let process = Process()
    process.executableURL = fooBinary

    let pipe = Pipe()
    process.standardOutput = pipe

    process.arguments = ["--version"]
    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)

    XCTAssertEqual(output?.trimmingCharacters(in: .whitespacesAndNewlines), cartonVersion)
  }
}
