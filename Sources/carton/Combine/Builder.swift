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

import Dispatch
import Foundation
import OpenCombine
import TSCBasic

struct BuilderError: Error, CustomStringConvertible {
  let description: String
}

struct Builder {
  let publisher: AnyPublisher<String, Error>

  private let process: TSCBasic.Process

  init(_ arguments: [String]) {
    let subject = PassthroughSubject<String, Error>()
    publisher = subject.eraseToAnyPublisher()

    let stdout: TSCBasic.Process.OutputClosure = {
      guard let string = String(data: Data($0), encoding: .utf8) else { return }
      subject.send(string)
    }

    let stderr: TSCBasic.Process.OutputClosure = {
      guard let string = String(data: Data($0), encoding: .utf8) else { return }
      subject.send(completion: .failure(BuilderError(description: string)))
    }

    process = Process(
      arguments: arguments,
      outputRedirection: .stream(stdout: stdout, stderr: stderr),
      verbose: true,
      startNewProcessGroup: true
    )
  }
}
