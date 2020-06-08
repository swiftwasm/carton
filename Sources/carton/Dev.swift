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

func processDataOutput(_ arguments: [String]) throws -> Data {
  let process = Process(arguments: arguments, startNewProcessGroup: false)
  try process.launch()
  let result = try process.waitUntilExit()
  return try Data(result.output.get())
}

func processStringsOutput(_ arguments: [String]) throws -> [String] {
  try String(data: processDataOutput(arguments), encoding: .utf8)?
    .components(separatedBy: CharacterSet.newlines) ?? []
}

struct Dev: ParsableCommand {
  @Option(help: "Specify name of an executable target in development.")
  var target: String?

  static var configuration = CommandConfiguration(
    abstract: "Watch the current directory, host the app, rebuild on change."
  )

  mutating func run() throws {
    guard let terminal = TerminalController(stream: stdoutStream)
    else { fatalError("failed to create an instance of `TerminalController`") }
    // try checkDevDependencies(on: localFileSystem, terminal)

    let fm = FileManager.default

    terminal.write("Inferring basic settings...\n", inColor: .yellow)
    let swiftPath: String
    if
      let data = fm.contents(atPath: ".swift-version"),
      // get the first line of the file
      let swiftVersion = String(data: data, encoding: .utf8)?.components(
        separatedBy: CharacterSet.newlines
      ).first {
      swiftPath = fm.homeDirectoryForCurrentUser
        .appending(".swiftenv", "versions", swiftVersion, "usr", "bin", "swift")
        .path
    } else {
      swiftPath = "swift"
    }
    terminal.logLookup("- swift executable: ", swiftPath)

    let output = try processDataOutput([swiftPath, "package", "dump-package"])
    let package = try JSONDecoder().decode(Package.self, from: output)
    var candidateNames = package.targets.filter { $0.type == .regular }.map(\.name)

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

    guard let binPath = try processStringsOutput([
      swiftPath, "build", "--triple", "wasm32-unknown-wasi", "--show-bin-path",
    ]).first else { fatalError("failed to decode UTF8 output of the `swift build` invocation") }

    let mainWasmURL = URL(fileURLWithPath: binPath).appendingPathComponent(candidateNames[0])
    terminal.logLookup("- development binary to serve: ", mainWasmURL.path)

    guard let sources = localFileSystem.currentWorkingDirectory?.appending(component: "Sources")
    else { fatalError("failed to infer the sources directory") }

    terminal.write("\nBuilding the project before spinning up a server...\n", inColor: .yellow)

    let builderArguments = [swiftPath, "build", "--triple", "wasm32-unknown-wasi"]
    var subscription: AnyCancellable?
    try await { completion in
      subscription = Builder(builderArguments, terminal).publisher
        .sink(
          receiveCompletion: { _ in completion(Result<(), Never>.success(())) },
          receiveValue: { _ in }
        )
    }

    guard fm.fileExists(atPath: mainWasmURL.path) else {
      return terminal.write(
        "Failed to build the main executable binary, fix the build errors and restart\n"
      )
    }

    terminal.write("\nWatching this directory for changes: ", inColor: .green)
    terminal.logLookup("", sources)
    terminal.write("\n")

    try Server(
      builderArguments: builderArguments,
      pathsToWatch: localFileSystem.traverseRecursively(sources),
      mainWasmPath: mainWasmURL.path,
      terminal
    ).run()
  }
}
