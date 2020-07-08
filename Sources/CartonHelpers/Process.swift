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

import Foundation
import TSCBasic

public func processDataOutput(_ arguments: [String]) throws -> [UInt8] {
  let process = Process(arguments: arguments, startNewProcessGroup: false)
  try process.launch()
  let result = try process.waitUntilExit()

  guard case .terminated(code: EXIT_SUCCESS) = result.exitStatus else {
    var description = "Process failed with non-zero exit status"
    if let output = try ByteString(result.output.get()).validDescription, !output.isEmpty {
      description += " and following output:\n\(output)"
    }

    if let output = try ByteString(result.stderrOutput.get()).validDescription {
      description += " and following error output:\n\(output)"
    }

    throw ProcessRunnerError(description: description)
  }

  return try result.output.get()
}
