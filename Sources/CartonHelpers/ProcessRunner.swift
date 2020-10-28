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
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif
import TSCBasic

public extension Subscribers.Completion {
  var result: Result<(), Failure> {
    switch self {
    case let .failure(error):
      return .failure(error)
    case .finished:
      return .success(())
    }
  }
}

struct ProcessRunnerError: Error, CustomStringConvertible {
  let description: String
}

public final class ProcessRunner {
  public let publisher: AnyPublisher<String, Error>

  private var subscription: AnyCancellable?

  // swiftlint:disable:next function_body_length
  public init(
    _ arguments: [String],
    loadingMessage: String = "Running...",
    parser: ProcessOutputParser? = nil,
    _ terminal: InteractiveWriter
  ) {
    let subject = PassthroughSubject<String, Error>()
    var tmpOutput = ""
    publisher = subject
      .handleEvents(
        receiveSubscription: { _ in
          terminal.clearLine()
          terminal.write(loadingMessage, inColor: .yellow)
        },
        receiveOutput: {
          if parser != nil {
            // Aggregate this for formatting later
            tmpOutput += $0
          } else {
            terminal.write($0)
          }
        }, receiveCompletion: {
          switch $0 {
          case .finished:
            let processName = arguments[0].first == "/" ?
              AbsolutePath(arguments[0]).basename : arguments[0]
            terminal.write("\n")
            if let parser = parser {
              if parser.parsingConditions.contains(.success) {
                parser.parse(tmpOutput, terminal)
              }
            } else {
              terminal.write(tmpOutput)
            }
            terminal.write(
              "\n`\(processName)` process finished successfully\n",
              inColor: .green,
              bold: false
            )
          case let .failure(error):
            let errorString = String(describing: error)
            if errorString.isEmpty {
              terminal.clearLine()
              terminal.write(
                "Compilation failed.\n\n",
                inColor: .red
              )
              if let parser = parser {
                if parser.parsingConditions.contains(.failure) {
                  parser.parse(tmpOutput, terminal)
                }
              } else {
                terminal.write(tmpOutput)
              }
            } else {
              terminal.write(
                "\nProcess failed and produced following output: \n",
                inColor: .red
              )
              print(error)
            }
          }
        }
      )
      .eraseToAnyPublisher()

    DispatchQueue.global().async {
      let stdout: TSCBasic.Process.OutputClosure = {
        guard let string = String(data: Data($0), encoding: .utf8) else { return }
        subject.send(string)
      }

      var stderrBuffer = [UInt8]()

      let stderr: TSCBasic.Process.OutputClosure = {
        stderrBuffer.append(contentsOf: $0)
      }

      let process = Process(
        arguments: arguments,
        outputRedirection: .stream(stdout: stdout, stderr: stderr),
        verbose: true,
        startNewProcessGroup: true
      )

      let result = Result<ProcessResult, Error> {
        try process.launch()
        return try process.waitUntilExit()
      }

      switch result.map(\.exitStatus) {
      case .success(.terminated(code: EXIT_SUCCESS)):
        subject.send(completion: .finished)
      case let .failure(error):
        subject.send(completion: .failure(error))
      default:
        let errorDescription = String(data: Data(stderrBuffer), encoding: .utf8) ?? ""
        return subject
          .send(completion: .failure(ProcessRunnerError(description: errorDescription)))
      }
    }
  }

  public func waitUntilFinished() throws {
    try await { completion in
      subscription = publisher
        .sink(
          receiveCompletion: { completion($0.result) },
          receiveValue: { _ in }
        )
    }
  }
}
