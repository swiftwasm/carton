// Copyright 2024 Carton contributors
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

import ArgumentParser
import XCTest
import CartonHelpers

struct CommandTestError: Swift.Error & CustomStringConvertible {
  init(_ description: String) {
    self.description = description
  }

  var description: String
}

extension XCTest {
  func findExecutable(name: String) throws -> AbsolutePath {
    let whichBin = "/usr/bin/which"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: whichBin)
    process.arguments = [name]
    let output = Pipe()
    process.standardOutput = output
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == EXIT_SUCCESS else {
      throw CommandTestError("Executable \(name) was not found: status=\(process.terminationStatus)")
    }
    let outputData = output.fileHandleForReading.readDataToEndOfFile()
    guard let string = String(data: outputData, encoding: .utf8) else {
      throw CommandTestError("Output from \(whichBin) is not UTF-8 string")
    }
    let path = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !path.isEmpty else {
      throw CommandTestError("Output from \(whichBin) is empty")
    }
    return try AbsolutePath(validating: path)
  }

  func findSwiftExecutable() throws -> AbsolutePath {
    try findExecutable(name: "swift")
  }

  struct SwiftRunResult {
    var exitCode: Int32
    var stdout: String
    var stderr: String

    func assertZeroExit(_ file: StaticString = #file, line: UInt = #line) {
      XCTAssertEqual(exitCode, 0, "stdout: " + stdout + "\nstderr: " + stderr, file: file, line: line)
    }
  }

  func swiftRunProcess(
    _ arguments: [CustomStringConvertible],
    packageDirectory: URL
  ) throws -> (Foundation.Process, stdout: Pipe, stderr: Pipe) {
    let process = Process()
    process.executableURL = try findSwiftExecutable().asURL
    process.arguments = ["run"] + arguments.map(\.description)
    process.currentDirectoryURL = packageDirectory
    let stdoutPipe = Pipe()
    process.standardOutput = stdoutPipe
    let stderrPipe = Pipe()
    process.standardError = stderrPipe

    func setSignalForwarding(_ signalNo: Int32) {
      signal(signalNo, SIG_IGN)
      let signalSource = DispatchSource.makeSignalSource(signal: signalNo)
      signalSource.setEventHandler {
        signalSource.cancel()
        process.interrupt()
      }
      signalSource.resume()
    }
    setSignalForwarding(SIGINT)
    setSignalForwarding(SIGTERM)

    trace("executableURL=\(process.executableURL?.description ?? "") arguments=\(process.arguments ?? []) currentDirectoryURL=\(process.currentDirectoryURL?.description ?? "")")

    try process.run()

    return (process, stdoutPipe, stderrPipe)
  }

  @discardableResult
  func swiftRun(_ arguments: [CustomStringConvertible], packageDirectory: URL) throws
    -> SwiftRunResult
  {
    let (process, stdoutPipe, stderrPipe) = try swiftRunProcess(
      arguments, packageDirectory: packageDirectory)
    process.waitUntilExit()

    let stdout = String(
      data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
      .trimmingCharacters(in: .whitespacesAndNewlines)

    let stderr = String(
      data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return SwiftRunResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
  }
}
