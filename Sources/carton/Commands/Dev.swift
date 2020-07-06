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
    0xBC, 0x78, 0x1D, 0x2D, 0xA2, 0x60, 0xB3, 0x15, 0x83, 0x26, 0x07, 0xA4, 0xB5, 0xB2, 0x24, 0x30,
    0xF1, 0x63, 0x61, 0x00, 0xBD, 0x4D, 0xB7, 0x73, 0xDB, 0x45, 0x79, 0x54, 0xB2, 0x5B, 0x05, 0xDE,
  ])
)

struct Dev: ParsableCommand {
  @Option(help: "Specify name of an executable product in development.")
  var product: String?

  @Option(help: "Specify name of a json destination file to be passed to `swift build`.")
  var destination: String?

  @Flag(help: "When specified, will build in release mode.")
  var release: Bool = false

  static var configuration = CommandConfiguration(
    abstract: "Watch the current directory, host the app, rebuild on change."
  )

  func run() throws {
    guard let terminal = TerminalController(stream: stdoutStream)
    else { fatalError("failed to create an instance of `TerminalController`") }

    // try dependency.check(on: localFileSystem, terminal)
    let swiftPath = try localFileSystem.inferSwiftPath(terminal)
    guard let product = try Package(with: swiftPath, terminal)
      .inferDevProduct(with: swiftPath, option: product, terminal)
    else { return }

    let binPath = try localFileSystem.inferBinPath(swiftPath: swiftPath)
    let mainWasmPath = binPath.appending(component: product)
    terminal.logLookup("- development binary to serve: ", mainWasmPath.pathString)

    terminal.preWatcherBuildNotice()

    var builderArguments = [swiftPath, "build", "-c", release ? "release" : "debug", "--triple",
                            "wasm32-unknown-wasi", "--product", product]
    if let destination = destination {
      builderArguments.append(contentsOf: ["--destination", destination])
    }

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
