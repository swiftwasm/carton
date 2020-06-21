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

import ArgumentParser
import Foundation
import OpenCombine
import TSCBasic

func processDataOutput(_ arguments: [String]) throws -> [UInt8] {
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

private let dependency = Dependency(
  fileName: "dev.js",
  sha256: ByteString([
    0xFE, 0x33, 0x13, 0x2F, 0x26, 0xAC, 0x54, 0xAF, 0x2F, 0xF4, 0x56, 0xF3, 0xD2, 0xEB, 0x20, 0x65,
    0xEB, 0x58, 0xE7, 0x82, 0xA9, 0x1C, 0x0C, 0xAC, 0xF3, 0xC1, 0x4B, 0xFF, 0x4C, 0xAE, 0x08, 0x9E,
  ])
)

struct Dev: ParsableCommand {
  @Option(help: "Specify name of an executable product in development.")
  var product: String?

  static var configuration = CommandConfiguration(
    abstract: "Watch the current directory, host the app, rebuild on change."
  )

  func run() throws {
    guard let terminal = TerminalController(stream: stdoutStream)
    else { fatalError("failed to create an instance of `TerminalController`") }

    try dependency.check(on: localFileSystem, terminal)
    let swiftPath = try localFileSystem.inferSwiftPath(terminal)
    guard let product = try Package(with: swiftPath, terminal)
      .inferDevProduct(with: swiftPath, flag: product, terminal)
    else { return }

    let binPath = try localFileSystem.inferBinPath(swiftPath: swiftPath)
    let mainWasmPath = binPath.appending(component: product)
    terminal.logLookup("- development binary to serve: ", mainWasmPath.pathString)

    terminal.preWatcherBuildNotice()

    let builderArguments =
      [swiftPath, "build", "--triple", "wasm32-unknown-wasi", "--product", product]

    try ProcessRunner(builderArguments, terminal).waitUntilFinished()

    guard localFileSystem.exists(mainWasmPath) else {
      return terminal.write(
        "Failed to build the main executable binary, fix the build errors and restart\n",
        inColor: .red
      )
    }

    guard let sources = localFileSystem.currentWorkingDirectory?.appending(component: "Sources")
    else { fatalError("failed to infer the sources directory") }

    terminal.write("\nWatching this directory for changes: ", inColor: .green)
    terminal.logLookup("", sources)
    terminal.write("\n")

    try Server(
      builderArguments: builderArguments,
      pathsToWatch: localFileSystem.traverseRecursively(sources),
      mainWasmPath: mainWasmPath.pathString,
      terminal
    ).run()
  }
}
