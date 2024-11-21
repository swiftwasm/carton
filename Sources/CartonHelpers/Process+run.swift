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
  let exitCode: Int32
}

extension ProcessError: CustomStringConvertible {
  var description: String {
    return "Process failed with exit code \(exitCode)"
  }
}

extension Foundation.Process {
  // swiftlint:disable:next function_body_length
  public static func run(
    _ arguments: [String],
    environment: [String: String] = [:],
    loadingMessage: String = "Running...",
    _ terminal: InteractiveWriter
  ) async throws {
    terminal.clearLine()
    terminal.write("Running \(arguments.joined(separator: " "))\n")

    if !environment.isEmpty {
      terminal.write(environment.map { "\($0)=\($1)" }.joined(separator: " ") + " ")
    }

    let processName = URL(fileURLWithPath: arguments[0]).lastPathComponent

    do {
      try await Process.checkNonZeroExit(
        arguments: arguments,
        environmentBlock: ProcessEnvironmentBlock(
          ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        ),
        loggingHandler: {
          terminal.write($0 + "\n")
        }
      )
      terminal.write(
        "`\(processName)` process finished successfully\n",
        inColor: .green,
        bold: false
      )
    } catch {
      terminal.clearLine()
      terminal.write(
        "\(processName) process failed.\n\n",
        inColor: .red
      )
      throw error
    }
  }
}
