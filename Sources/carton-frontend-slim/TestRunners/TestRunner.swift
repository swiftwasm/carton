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

struct TestRunnerOptions {
  /// The environment variables to pass to the test process.
  let env: [String: String]
  /// When specified, list all available test cases.
  let listTestCases: Bool
  /// Filter the test cases to run.
  let testCases: [String]

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
