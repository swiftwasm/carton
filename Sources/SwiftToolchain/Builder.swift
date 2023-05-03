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
import Foundation
import TSCBasic
import WasmTransformer

public final class Builder {
  public let mainWasmPath: AbsolutePath
  public let pathsToWatch: [AbsolutePath]
  private let arguments: [String]
  private let flavor: BuildFlavor
  private let terminal: InteractiveWriter
  private let fileSystem: FileSystem

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

  private func buildWithoutSanitizing(builderArguments: [String]) async throws {
    let buildStarted = Date()
    try await Process.run(
      builderArguments,
      loadingMessage: "Compiling...",
      parser: nil,
      terminal
    )

    terminal.logLookup(
      "`swift build` completed in ",
      String(format: "%.2f seconds", abs(buildStarted.timeIntervalSinceNow))
    )

    var transformers: [(inout InputByteStream, inout InMemoryOutputWriter) throws -> Void] = []
    if flavor.environment == .node || flavor.environment == .defaultBrowser {
      // If building for JS-host environments,
      // - i64 params in imports are not supported without bigint-i64 feature
      // - The param types in imports don't have to be strictly same as host expected
      // - Users cannot avoid having such imports come from WASI since they are
      //   mandatory imports.
      //
      // So lower i64 param types to be i32. It happens *only for WASI imports*
      // since users can avoid such imports coming from other user modules.
      let transformer = I64ImportTransformer(shouldLower: {
        $0.module == "wasi_snapshot_preview1" || $0.module == "wasi_unstable"
      })
      transformers.append(transformer.transform)
    }
    // Strip unnecessary autolink sections, which is only used at link-time
    transformers.append(
      CustomSectionStripper(stripIf: {
        $0 == ".swift1_autolink_entries"
      }).transform)

    switch flavor.sanitize {
    case .stackOverflow:
      transformers.append(StackOverflowSanitizer().transform)
    case .none:
      break
    }

    guard !transformers.isEmpty else { return }

    let binary = try fileSystem.readFileContents(mainWasmPath)

    let transformStarted = Date()
    var inputBinary = binary.contents
    for transformer in transformers {
      var input = InputByteStream(bytes: inputBinary)
      var writer = InMemoryOutputWriter(reservingCapacity: inputBinary.count)
      try transformer(&input, &writer)
      inputBinary = writer.bytes()
    }

    terminal.logLookup(
      "Binary transformation for Safari compatibility completed in ",
      String(format: "%.2f seconds", abs(transformStarted.timeIntervalSinceNow))
    )

    try fileSystem.writeFileContents(mainWasmPath, bytes: .init(inputBinary))
  }

  public func run() async throws {
    switch flavor.sanitize {
    case .none:
      return try await buildWithoutSanitizing(builderArguments: arguments)
    case .stackOverflow:
      let sanitizerFile =
        try fileSystem.homeDirectory.appending(components: ".carton", "static", "so_sanitizer.wasm")

      var modifiedArguments = arguments
      modifiedArguments.append(contentsOf: [
        "-Xlinker", sanitizerFile.pathString,
        // stack-overflow-sanitizer depends on "--stack-first"
        "-Xlinker", "--stack-first",
      ])
      return try await buildWithoutSanitizing(builderArguments: modifiedArguments)
    }
  }
}
