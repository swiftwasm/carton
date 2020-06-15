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
    throw ProcessRunnerError(description: "Process failed with non-zero exit status")
  }

  return try result.output.get()
}

private let dependency = Dependency(
  fileName: "dev.js",
  sha256: ByteString([
    0xAF, 0xFC, 0x8E, 0xDA, 0x95, 0x69, 0x5E, 0xB1, 0xF4, 0x5D, 0x3F, 0xAF, 0x44, 0xDF, 0x11, 0xB6,
    0xC6, 0x11, 0xDA, 0x4B, 0x50, 0x3C, 0x31, 0x76, 0x0B, 0x55, 0x07, 0xB7, 0xA4, 0xB7, 0xC3, 0x0E,
  ])
)

struct Dev: ParsableCommand {
  @Option(help: "Specify name of an executable target in development.")
  var target: String?

  static var configuration = CommandConfiguration(
    abstract: "Watch the current directory, host the app, rebuild on change."
  )

  func run() throws {
    guard let terminal = TerminalController(stream: stdoutStream)
    else { fatalError("failed to create an instance of `TerminalController`") }

    try dependency.check(on: localFileSystem, terminal)
    let swiftPath = try localFileSystem.inferSwiftPath(terminal)
    var candidateNames = try Package(with: swiftPath, terminal).targets
      .filter { $0.type == .regular }
      .map(\.name)

    if let target = target {
      candidateNames = candidateNames.filter { $0 == target }

      guard candidateNames.count == 1 else {
        fatalError("""
        failed to disambiguate the development target,
        make sure `\(target)` is present in Package.swift
        """)
      }
    }
    guard candidateNames.count == 1 else {
      fatalError("""
      failed to disambiguate the development target,
      pass one of \(candidateNames) to the --target flag
      """)
    }
    terminal.logLookup("- development target: ", candidateNames[0])

    let binPath = try localFileSystem.inferBinPath(swiftPath: swiftPath)
    let mainWasmPath = binPath.appending(component: candidateNames[0])
    terminal.logLookup("- development binary to serve: ", mainWasmPath.pathString)

    terminal.preWatcherBuildNotice()

    let builderArguments = [swiftPath, "build", "--triple", "wasm32-unknown-wasi"]

    try ProcessRunner(builderArguments, terminal).waitUntilFinished()

    guard localFileSystem.exists(mainWasmPath) else {
      return terminal.write(
        "Failed to build the main executable binary, fix the build errors and restart\n"
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
