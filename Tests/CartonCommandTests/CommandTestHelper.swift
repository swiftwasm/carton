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
import CartonHelpers
import Foundation
import XCTest

struct CommandTestError: Swift.Error & CustomStringConvertible {
  init(_ description: String) {
    self.description = description
  }

  var description: String
}

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

func makeTeeProcess(file: AbsolutePath) throws -> Foundation.Process {
  let process = Process()
  process.executableURL = try findExecutable(name: "tee").asURL
  process.arguments = [file.pathString]
  return process
}

private let processConcurrentQueue = DispatchQueue(
  label: "carton.processConcurrentQueue",
  attributes: .concurrent
)

struct FoundationProcessResult: CustomStringConvertible {
  struct Error: Swift.Error & CustomStringConvertible {
    var result: FoundationProcessResult

    var description: String {
      result.description
    }
  }

  var executable: String
  var arguments: [String]
  var statusCode: Int32
  var output: Data?
  var errorOutput: Data?

  func utf8Output() -> String? {
    guard let output else { return nil }
    return String(decoding: output, as: UTF8.self)
  }

  func utf8ErrorOutput() -> String? {
    guard let errorOutput else { return nil }
    return String(decoding: errorOutput, as: UTF8.self)
  }

  var description: String {
    let commandLine = ([executable] + arguments).joined(separator: " ")

    let summary = if statusCode == EXIT_SUCCESS {
      "Process succeeded."
    } else {
      "Process failed with status code \(statusCode)."
    }

    var lines: [String] = [
      summary,
      "Command line: \(commandLine)"
    ]

    if let string = utf8Output() {
      lines += ["Output:", string]
    }
    if let string = utf8ErrorOutput() {
      lines += ["Error output:", string]
    }
    return lines.joined(separator: "\n")
  }

  func checkSuccess() throws {
    guard statusCode == EXIT_SUCCESS else {
      throw Error(result: self)
    }
  }
}


extension Foundation.Process {
  func waitUntilExit() async {
    await withCheckedContinuation { (continuation) in
      processConcurrentQueue.async {
        self.waitUntilExit()
        continuation.resume()
      }
    }
  }

  func result(
    output: Data? = nil,
    errorOutput: Data? = nil
  ) throws -> FoundationProcessResult {
    guard let executableURL else {
      throw CommandTestError("executableURL is nil")
    }
    return FoundationProcessResult(
      executable: executableURL.path,
      arguments: arguments ?? [],
      statusCode: terminationStatus,
      output: output,
      errorOutput: errorOutput
    )
  }
}

struct SwiftRunProcess {
  var process: Foundation.Process
  var tee: Foundation.Process
  var outputFile: AbsolutePath

  func output() throws -> Data {
    try Data(contentsOf: outputFile.asURL)
  }

  func waitUntilExit() async {
    await process.waitUntilExit()
    await tee.waitUntilExit()
  }

  func result() throws -> FoundationProcessResult {
    return try process.result(output: try output())
  }
}

func swiftRunProcess(
  _ arguments: [String],
  packageDirectory: URL
) throws -> SwiftRunProcess {
  let outputFile = try AbsolutePath(
    validating: try FileUtils.makeTemporaryFile(prefix: "swift-run").path
  )
  let tee = try makeTeeProcess(file: outputFile)

  let teePipe = Pipe()
  tee.standardInput = teePipe

  let process = Process()
  process.executableURL = try findSwiftExecutable().asURL
  process.arguments = ["run"] + arguments.map(\.description)
  process.currentDirectoryURL = packageDirectory
  process.standardOutput = teePipe

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

  try process.run()

  return SwiftRunProcess(process: process, tee: tee, outputFile: outputFile)
}

func swiftRun(_ arguments: [String], packageDirectory: URL) async throws -> FoundationProcessResult {
  let process = try swiftRunProcess(arguments, packageDirectory: packageDirectory)
  await process.waitUntilExit()
  return try process.result()
}
