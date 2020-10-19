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
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif
import Foundation
import TSCBasic
import WasmTransformer

public final class Builder {
  public enum Environment {
    case other
    case browser
  }

  public let mainWasmPath: AbsolutePath

  private var currentProcess: ProcessRunner?
  private let arguments: [String]
  private let environment: Environment
  private let terminal: InteractiveWriter
  private let fileSystem: FileSystem
  private var subscription: AnyCancellable?

  public init(
    arguments: [String],
    mainWasmPath: AbsolutePath,
    environment: Environment = .browser,
    _ fileSystem: FileSystem,
    _ terminal: InteractiveWriter
  ) {
    self.arguments = arguments
    self.mainWasmPath = mainWasmPath
    self.environment = environment
    self.terminal = terminal
    self.fileSystem = fileSystem
  }

  public func run() -> AnyPublisher<String, Error> {
    let buildStarted = Date()
    let process = ProcessRunner(arguments, loadingMessage: "Compiling...", terminal)
    currentProcess = process

    return process
      .publisher
      .handleEvents(receiveCompletion: { [weak self] in
        guard case .finished = $0, let self = self else { return }

        self.terminal.logLookup(
          "`swift build` completed in ",
          String(format: "%.2f seconds", abs(buildStarted.timeIntervalSinceNow))
        )

        guard self.environment == .browser else { return }

        // FIXME: errors from these `try` expressions should be recoverable, not sure how to
        // do that in `handleEvents`, and `flatMap` doesnt' fit here as we need to track
        // publisher completion.
        // swiftlint:disable force_try
        let binary = try! self.fileSystem.readFileContents(self.mainWasmPath)

        let loweringStarted = Date()
        let loweredBinary = try! lowerI64Imports(binary.contents)

        self.terminal.logLookup(
          "Binary transformation for Safari compatibility completed in ",
          String(format: "%.2f seconds", abs(loweringStarted.timeIntervalSinceNow))
        )

        try! self.fileSystem.writeFileContents(self.mainWasmPath, bytes: .init(loweredBinary))
        // swiftlint:enable force_try
      })
      .eraseToAnyPublisher()
  }

  public func runAndWaitUntilFinished() throws {
    try await { completion in
      subscription = run()
        .sink(
          receiveCompletion: { completion($0.result) },
          receiveValue: { _ in }
        )
    }
  }
}
