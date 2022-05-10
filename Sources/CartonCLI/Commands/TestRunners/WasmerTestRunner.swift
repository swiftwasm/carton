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
import CartonKit
import Foundation
import TSCBasic

struct WasmerTestRunner: TestRunner {
  let testFilePath: AbsolutePath
  let listTestCases: Bool
  let testCases: [String]
  let terminal: InteractiveWriter

  func run() async throws {
    terminal.write("\nRunning the test bundle with wasmer:\n", inColor: .yellow)
    var wasmerArguments = ["wasmer", testFilePath.pathString]
    if listTestCases {
      wasmerArguments.append(contentsOf: ["--", "-l"])
    } else if !testCases.isEmpty {
      wasmerArguments.append("--")
      wasmerArguments.append(contentsOf: testCases)
    }
    try await Process.run(wasmerArguments, parser: TestsParser(), terminal)
  }

}
