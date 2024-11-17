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
import Dispatch
import Foundation

struct ProcessError: Error {
  let stderr: String?
  let stdout: String?
}

extension ProcessError: CustomStringConvertible {
  var description: String {
    var result = "Process failed with non-zero exit status"
    if let stdout = stdout {
      result += " and following output:\n\(stdout)"
    }

    if let stderr = stderr {
      result += " and following error output:\n\(stderr)"
    }
    return result
  }
}

extension Foundation.Process {
  // swiftlint:disable:next function_body_length
  public static func run(
    _ arguments: [String],
    environment: [String: String] = [:],
    loadingMessage: String = "Running...",
    parser: ProcessOutputParser? = nil,
    _ terminal: InteractiveWriter
  ) async throws {
    terminal.clearLine()
    terminal.write("\(loadingMessage)\n", inColor: .yellow)

    if !environment.isEmpty {
      terminal.write(environment.map { "\($0)=\($1)" }.joined(separator: " ") + " ")
    }

    let processName = URL(fileURLWithPath: arguments[0]).lastPathComponent

    do {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<(), Swift.Error>) in
        DispatchQueue.global().async {
          var stdoutBuffer = ""

          let stdout: Process.OutputClosure = {
            guard let string = String(data: Data($0), encoding: .utf8) else { return }
            if parser != nil {
              // Aggregate this for formatting later
              stdoutBuffer += string
            } else {
              terminal.write(string)
            }
          }

          var stderrBuffer = [UInt8]()

          let stderr: Process.OutputClosure = {
            stderrBuffer.append(contentsOf: $0)
          }

          let process = Process(
            arguments: arguments,
            environmentBlock: ProcessEnvironmentBlock(
              ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
            ),
            outputRedirection: .stream(stdout: stdout, stderr: stderr),
            startNewProcessGroup: true,
            loggingHandler: {
              terminal.write($0 + "\n")
            }
          )

          let result = Result<ProcessResult, Swift.Error> {
            try process.launch()
            return try process.waitUntilExit()
          }

          switch result.map(\.exitStatus) {
          case .success(.terminated(code: EXIT_SUCCESS)):
            if let parser = parser {
              if parser.parsingConditions.contains(.success) {
                parser.parse(stdoutBuffer, terminal)
              }
            } else {
              terminal.write(stdoutBuffer)
            }
            terminal.write(
              "`\(processName)` process finished successfully\n",
              inColor: .green,
              bold: false
            )
            continuation.resume()

          case let .failure(error):
            continuation.resume(throwing: error)
          default:
            continuation.resume(
              throwing: ProcessError(
                stderr: String(data: Data(stderrBuffer), encoding: .utf8) ?? "",
                stdout: stdoutBuffer
              )
            )
          }
        }
      }
    } catch {
      let errorString = String(describing: error)
      if errorString.isEmpty {
        terminal.clearLine()
        terminal.write(
          "\(processName) process failed.\n\n",
          inColor: .red
        )
        if let error = error as? ProcessError, let stdout = error.stdout {
          if let parser = parser {
            if parser.parsingConditions.contains(.failure) {
              parser.parse(stdout, terminal)
            }
          } else {
            terminal.write(stdout)
          }
        }
      }

      throw error
    }
  }
}
