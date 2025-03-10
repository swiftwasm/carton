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

import CartonCore
import CartonHelpers
import Foundation

struct TestRunnerOptions {
  /// The environment variables to pass to the test process.
  let env: [String: String]
  /// When specified, list all available test cases.
  let listTestCases: Bool
  /// Filter the test cases to run.
  let testCases: [String]
  /// The parser to use for the test output.
  let testsParser: any TestsParser

  func applyXCTestArguments(to arguments: inout [String]) {
    if listTestCases {
      arguments.append(contentsOf: ["--", "-l"])
    } else if !testCases.isEmpty {
      arguments.append(contentsOf: testCases)
    }
  }
}

protocol TestRunner {
  func run(options: TestRunnerOptions) async throws
}

struct LineStream {
  var buffer: String = ""
  let onLine: (String) -> Void

  mutating func feed(_ bytes: [UInt8]) {
    buffer += String(decoding: bytes, as: UTF8.self)
    while let newlineIndex = buffer.firstIndex(of: "\n") {
      let line = buffer[..<newlineIndex]
      buffer.removeSubrange(buffer.startIndex...newlineIndex)
      onLine(String(line))
    }
  }
}

extension TestRunner {
  func runTestProcess(
    _ arguments: [String],
    environment: [String: String] = [:],
    parser: any TestsParser,
    _ terminal: InteractiveWriter
  ) async throws {
    do {
      terminal.clearLine()
      let commandLine = arguments.map { "\"\($0)\"" }.joined(separator: " ")
      terminal.write("Running \(commandLine)\n")

      let (lines, continuation) = AsyncStream.makeStream(
        of: String.self, bufferingPolicy: .unbounded
      )
      var lineStream = LineStream { line in
        continuation.yield(line)
      }
      let process = Process(
        arguments: arguments,
        environmentBlock: ProcessEnvironmentBlock(
          ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        ),
        outputRedirection: .stream(
          stdout: { bytes in
            lineStream.feed(bytes)
          }, stderr: { _ in },
          redirectStderr: true
        ),
        startNewProcessGroup: true
      )
      async let _ = parser.parse(lines, terminal)
      try process.launch()
      let result = try await process.waitUntilExit()
      guard result.exitStatus == .terminated(code: 0) else {
        throw ProcessResult.Error.nonZeroExit(result)
      }
    }
  }
}
