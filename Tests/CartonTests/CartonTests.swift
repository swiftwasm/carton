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
@testable import CartonKit
import class Foundation.Bundle
@testable import SwiftToolchain
import TSCBasic
import TSCUtility
import XCTest

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

  final class TestOutputStream: OutputByteStream {
    var bytes: [UInt8] = []
    var currentOutput: String {
      String(bytes: bytes, encoding: .utf8)!
    }

    var position: Int = 0

    init() {}

    func flush() {}

    func write(_ byte: UInt8) {
      bytes.append(byte)
    }

    func write<C>(_ bytes: C) where C: Collection, C.Element == UInt8 {
      self.bytes.append(contentsOf: bytes)
    }
  }

  func testDiagnosticsParser() {
    // swiftlint:disable line_length
    let testDiagnostics = """
    [1/1] Compiling TokamakCore Font.swift
    /Users/username/Project/Sources/TokamakCore/Tokens/Font.swift:58:15: error: invalid redeclaration of 'resolve(in:)'
      public func resolve(in environment: EnvironmentValues) -> _Font {
                  ^
    /Users/username/Project/Sources/TokamakCore/Tokens/Font.swift:55:15: note: 'resolve(in:)' previously declared here
      public func resolve(in environment: EnvironmentValues) -> _Font {
                  ^
    """
    let expectedOutput = """
    \u{001B}[1m\u{001B}[7m Font.swift \u{001B}[0m /Users/username/Project/Sources/TokamakCore/Tokens/Font.swift:58

      \u{001B}[41;1m\u{001B}[37;1m ERROR \u{001B}[0m  invalid redeclaration of 'resolve(in:)'
      \u{001B}[36m58 | \u{001B}[0m   \u{001B}[35;1mpublic\u{001B}[0m \u{001B}[35;1mfunc\u{001B}[0m resolve(in environment: \u{001B}[94mEnvironmentValues\u{001B}[0m) -> \u{001B}[94m_Font\u{001B}[0m {
         |                ^

      \u{001B}[7m\u{001B}[37;1m NOTE \u{001B}[0m  'resolve(in:)' previously declared here
      \u{001B}[36m55 | \u{001B}[0m   \u{001B}[35;1mpublic\u{001B}[0m \u{001B}[35;1mfunc\u{001B}[0m resolve(in environment: \u{001B}[94mEnvironmentValues\u{001B}[0m) -> \u{001B}[94m_Font\u{001B}[0m {
         |                ^



    """
    // swiftlint:enable line_length
    let stream = TestOutputStream()
    let writer = InteractiveWriter(stream: stream)
    DiagnosticsParser().parse(testDiagnostics, writer)
    XCTAssertEqual(stream.currentOutput, expectedOutput)
  }

  func testDestinationEnvironment() {
    XCTAssertEqual(
      DestinationEnvironment(
        userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:93.0) Gecko/20100101 Firefox/93.0"
      ),
      .firefox
    )
    XCTAssertEqual(
      DestinationEnvironment(
        userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.71 Safari/537.36 Edg/94.0.992.38"
      ),
      .edge
    )
    XCTAssertEqual(
      DestinationEnvironment(
        userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.71 Safari/537.36"
      ),
      .chrome
    )
    XCTAssertEqual(
      DestinationEnvironment(
        userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15"
      ),
      .safari
    )
    XCTAssertEqual(
      DestinationEnvironment(userAgent: "Opera/9.30 (Nintendo Wii; U; ; 3642; en)"),
      nil
    )
  }
  
  func testSwiftWasmVersionParsing() throws {
    let v5_6 = try Version(swiftWasmVersion: "wasm-5.6.0-RELEASE")
    XCTAssertEqual(v5_6.major, 5)
    XCTAssertEqual(v5_6.minor, 6)
    XCTAssertEqual(v5_6.patch, 0)
    XCTAssert(v5_6.prereleaseIdentifiers.isEmpty)
    XCTAssert(v5_6 >= Version(5, 6, 0))
    
    let v5_7_snapshot = try Version(swiftWasmVersion: "wasm-5.7-SNAPSHOT-2022-07-14-a")
    XCTAssertEqual(v5_7_snapshot.major, 5)
    XCTAssertEqual(v5_7_snapshot.minor, 7)
    XCTAssertEqual(v5_7_snapshot.patch, 0)
    XCTAssert(v5_7_snapshot.prereleaseIdentifiers.isEmpty)
    XCTAssert(v5_7_snapshot >= Version(5, 6, 0))
  }
}
