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

private enum Constants {
  static let entrypoint = Entrypoint(fileName: "testNode.js", sha256: testNodeEntrypointSHA256)
}

struct NodeTestRunner: TestRunner {
  let testFilePath: AbsolutePath
  let listTestCases: Bool
  let testCases: [String]
  let terminal: InteractiveWriter

  func run() async throws {
    terminal.write("\nRunning the test bundle with NodeJS:\n", inColor: .yellow)
    let (_, _, filePath) = Constants.entrypoint.paths(on: localFileSystem)
    var nodeArguments = ["node", filePath.pathString, testFilePath.pathString]
    if listTestCases {
      nodeArguments.append(contentsOf: ["--", "-l"])
    } else if !testCases.isEmpty {
      nodeArguments.append("--")
      nodeArguments.append(contentsOf: testCases)
    }
    try await Process.run(nodeArguments, terminal)
  }

}
