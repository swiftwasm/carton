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
  public let mainWasmPath: AbsolutePath
  public let pathsToWatch: [AbsolutePath]

  private var currentProcess: ProcessRunner?
  private let arguments: [String]
  private let flavor: BuildFlavor
  private let terminal: InteractiveWriter
  private let fileSystem: FileSystem
  private var subscription: AnyCancellable?

  public init(
    arguments: [String],
    mainWasmPath: AbsolutePath,
    pathsToWatch: [AbsolutePath] = [],
    _ flavor: BuildFlavor,
    _ fileSystem: FileSystem,
    _ terminal: InteractiveWriter
  ) {
    self.arguments = arguments
    self.mainWasmPath = mainWasmPath
    self.pathsToWatch = pathsToWatch
    self.flavor = flavor
    self.terminal = terminal
    self.fileSystem = fileSystem
  }

  private func processPublisher(builderArguments: [String]) -> AnyPublisher<String, Error> {
    let buildStarted = Date()
    let process = ProcessRunner(
      builderArguments,
      loadingMessage: "Compiling...",
      parser: nil,
      terminal
    )
    currentProcess = process

    return process
      .publisher
      .handleEvents(receiveCompletion: { [weak self] in
        guard case .finished = $0, let self = self else { return }

        self.terminal.logLookup(
          "`swift build` completed in ",
          String(format: "%.2f seconds", abs(buildStarted.timeIntervalSinceNow))
        )

        var transformers: [(inout InputByteStream, inout InMemoryOutputWriter) throws -> ()] = []
        if self.flavor.environment != .other {
          transformers.append(I64ImportTransformer().transform)
        }

        switch self.flavor.sanitize {
        case .stackOverflow:
          transformers.append(StackOverflowSanitizer().transform)
        case .none:
          break
        }

        guard !transformers.isEmpty else { return }

        // FIXME: errors from these `try` expressions should be recoverable, not sure how to
        // do that in `handleEvents`, and `flatMap` doesn't fit here as we need to track
        // publisher completion.
        // swiftlint:disable force_try
        let binary = try! self.fileSystem.readFileContents(self.mainWasmPath)

        let transformStarted = Date()
        var inputBinary = binary.contents
        for transformer in transformers {
          var input = InputByteStream(bytes: inputBinary)
          var writer = InMemoryOutputWriter(reservingCapacity: inputBinary.count)
          try! transformer(&input, &writer)
          inputBinary = writer.bytes()
        }

        self.terminal.logLookup(
          "Binary transformation for Safari compatibility completed in ",
          String(format: "%.2f seconds", abs(transformStarted.timeIntervalSinceNow))
        )

        try! self.fileSystem.writeFileContents(self.mainWasmPath, bytes: .init(inputBinary))
        // swiftlint:enable force_try
      })
      .eraseToAnyPublisher()
  }

  public func run() -> AnyPublisher<String, Error> {
    switch flavor.sanitize {
    case .none:
      return processPublisher(builderArguments: arguments)
    case .stackOverflow:
      let sanitizerFile =
        fileSystem.homeDirectory.appending(components: ".carton", "static", "so_sanitizer.wasm")

      var modifiedArguments = arguments
      modifiedArguments.append(contentsOf: [
        "-Xlinker", sanitizerFile.pathString,
        // stack-overflow-sanitizer depends on "--stack-first"
        "-Xlinker", "--stack-first",
      ])
      return processPublisher(builderArguments: modifiedArguments)
    }
  }

  public func runAndWaitUntilFinished() throws {
    try tsc_await { completion in
      subscription = run()
        .sink(
          receiveCompletion: { completion($0.result) },
          receiveValue: { _ in }
        )
    }
  }
}
