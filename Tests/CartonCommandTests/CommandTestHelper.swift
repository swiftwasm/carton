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

struct SwiftRunProcess {
  var process: CartonHelpers.Process
  var output: () -> [UInt8]
}

func swiftRunProcess(
  _ arguments: [String],
  packageDirectory: URL
) throws -> SwiftRunProcess {
  let swiftBin = try findSwiftExecutable().pathString

  var outputBuffer = Array<UInt8>()

  let process = CartonHelpers.Process(
    arguments: [swiftBin, "run"] + arguments,
    workingDirectory: try AbsolutePath(validating: packageDirectory.path),
    outputRedirection: .stream(
      stdout: { (chunk) in
        outputBuffer += chunk
        stdoutStream.write(sequence: chunk)
      }, stderr: { (chunk) in
        stderrStream.write(sequence: chunk)
      },
      redirectStderr: false
    )
  )

  try process.launch()

  func setSignalForwarding(_ signalNo: Int32) {
    signal(signalNo, SIG_IGN)
    let signalSource = DispatchSource.makeSignalSource(signal: signalNo)
    signalSource.setEventHandler {
      signalSource.cancel()
      process.signal(SIGINT)
    }
    signalSource.resume()
  }
  setSignalForwarding(SIGINT)
  setSignalForwarding(SIGTERM)

  return SwiftRunProcess(
    process: process,
    output: { outputBuffer }
  )
}

@discardableResult
func swiftRun(_ arguments: [String], packageDirectory: URL) async throws
  -> CartonHelpers.ProcessResult
{
  let process = try swiftRunProcess(arguments, packageDirectory: packageDirectory)
  var result = try await process.process.waitUntilExit()
  result.setOutput(.success(process.output()))
  return result
}
