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

struct CommandTestRunnerError: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}

struct CommandTestRunner: TestRunner {
  let testFilePath: AbsolutePath
  let terminal: InteractiveWriter

  func run(options: TestRunnerOptions) async throws {
    let program =
      try ProcessInfo.processInfo.environment["CARTON_TEST_RUNNER"] ?? defaultWASIRuntime()
    terminal.write("\nRunning the test bundle with \"\(program)\":\n", inColor: .yellow)

    var arguments = [program]
    var xctestArgs: [String] = []
    options.applyXCTestArguments(to: &xctestArgs)
    if !xctestArgs.isEmpty {
      xctestArgs = ["--"] + xctestArgs
    }
    let programName = URL(fileURLWithPath: program).lastPathComponent
    if programName == "wasmtime" {
      arguments += ["--dir", "."]
    }
    arguments += ["--wasi", "inherit-env"]
    for (key, value) in options.env {
      arguments += ["--env", "\(key)=\(value)"]
    }

    arguments += [testFilePath.pathString] + xctestArgs
    try await Process.run(arguments, parser: TestsParser(), terminal)
  }

  func defaultWASIRuntime() throws -> String {
    let candidates = ["wasmtime", "wasmer"]
    guard let found = candidates.lazy.compactMap({ try? Foundation.Process.which($0) }).first else {
      throw CommandTestRunnerError(
        "No WASI runtime found. Please install one of the following: \(candidates.joined(separator: ", "))"
      )
    }
    return found.path
  }
}
