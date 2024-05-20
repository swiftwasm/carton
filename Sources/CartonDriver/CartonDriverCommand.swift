// Copyright 2024 Carton contributors
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

// This executable is a thin wrapper around the Swift Package Manager and the Carton's SwiftPM Plugins.
// The responsibilities of this executable are:
// - to install appropriate SwiftWasm toolchain if it's not installed and to use it for the later invocations
//   * This step will be eventually removed once SwiftPM provides a good way to manage Swift SDKs declaratively
//     and Xcode toolchain provides WebAssembly target. (OSS toolchain already provides it)
// - to grant the SwiftPM Plugin process appropriate permissions to write to the file system
//   * "dev" and "test" subcommands require listening TCP sockets but SwiftPM doesn't provide a way to
//     express this requirement in the package manifest
//   * "bundle" subcommand requires writing to the file system to "./Bundle" directory. This is to keep
//     soft compatibility with the default behavior of the previous version of Carton
// - to give the SwiftPM build system the target triple by default
//   * SwiftPM doesn't provide a way to control the target triple from plugin process
// - to pre-build "{package-name}PackageTests" product before running plugin process
//   * SwiftPM doesn't support building only "all tests" product from plugin process, so we have to
//     build it before running the CartonTest plugin process
//
// This executable should be eventually removed once SwiftPM provides a way to express those requirements.

import CartonHelpers
import Foundation
import SwiftToolchain

struct CartonDriverError: Error & CustomStringConvertible {
  init(_ description: String) {
    self.description = description
  }
  var description: String
}

extension Foundation.Process {
  internal static func checkRun(
    _ executableURL: URL, arguments: [String], forwardExit: Bool = false
  ) throws {
    let commandLine: String = ([executableURL.path] + arguments)
      .map { "\"\($0)\"" }.joined(separator: " ")

    fputs("Running \(commandLine)\n", stderr)
    fflush(stderr)

    let process = Foundation.Process()
    process.executableURL = executableURL
    process.arguments = arguments

    // Monitor termination/interrruption signals to forward them to child process
    func setSignalForwarding(_ signalNo: Int32) {
      signal(signalNo, SIG_IGN)
      let signalSource = DispatchSource.makeSignalSource(signal: signalNo)
      signalSource.setEventHandler {
        signalSource.cancel()
        process.interrupt()
      }
      signalSource.resume()
    }
    setSignalForwarding(SIGINT)
    setSignalForwarding(SIGTERM)

    try process.run()
    process.waitUntilExit()

    if forwardExit {
      exit(process.terminationStatus)
    }

    if process.terminationStatus != 0 {
      throw CartonDriverError(
        "Process failed with status \(process.terminationStatus).\n" +
        "Command line: \(commandLine)"
      )
    }
  }
}

func derivePackageCommandArguments(
  swiftExec: URL,
  subcommand: String,
  scratchPath: String,
  extraArguments: [String]
) throws -> [String] {
  var packageArguments: [String] = [
    "package", "--triple", "wasm32-unknown-wasi", "--scratch-path", scratchPath,
  ]
  let pluginArguments: [String] = ["plugin"]
  var cartonPluginArguments: [String] = extraArguments

  switch subcommand {
  case "bundle":
    packageArguments += ["--disable-sandbox"]
    // TODO: Uncomment this line once we stop creating .carton directory in the home directory
    // pluginArguments += ["--allow-writing-to-package-directory"]

    // Place before user-given extra arguments to allow overriding default options
    cartonPluginArguments = ["--output", "Bundle"] + cartonPluginArguments
  case "dev":
    packageArguments += ["--disable-sandbox"]
  case "test":
    // 1. Ask the plugin process to generate the build command based on the given options
    let commandFile = try makeTemporaryFile(prefix: "test-build")
    try Foundation.Process.checkRun(
      swiftExec,
      arguments: packageArguments + pluginArguments + [
        "carton-test",
        "internal-get-build-command",
      ] + cartonPluginArguments + ["--output", commandFile.path]
    )

    // 2. Build the test product
    let buildArguments = try String(contentsOf: commandFile).split(separator: "\n")
    if !buildArguments.isEmpty {
      let buildCommand = buildArguments.map(String.init) + [
        // NOTE: "swift-build" uses llbuild manifest cache by default even though
        // target triple changed.
        "--disable-build-manifest-caching",
        "--triple", "wasm32-unknown-wasi", "--scratch-path", scratchPath,
      ]
      try Foundation.Process.checkRun(
        swiftExec,
        arguments: buildCommand
      )
    }

    // "--environment browser" launches a http server
    packageArguments += ["--disable-sandbox"]
  default: break
  }

  return packageArguments + pluginArguments + ["carton-\(subcommand)"] + cartonPluginArguments
}

var errnoString: String {
  String(cString: strerror(errno))
}

var temporaryDirectory: URL {
  URL(fileURLWithPath: NSTemporaryDirectory())
}

func makeTemporaryFile(prefix: String, in directory: URL? = nil) throws -> URL {
  let directory = directory ?? temporaryDirectory
  var template = directory.appendingPathComponent("\(prefix)XXXXXX").path
  let result = try template.withUTF8 { template in
    let copy = UnsafeMutableBufferPointer<CChar>.allocate(capacity: template.count + 1)
    defer { copy.deallocate() }
    template.copyBytes(to: copy)
    copy[template.count] = 0
    guard mkstemp(copy.baseAddress!) != -1 else {
      let error = errnoString
      throw CartonDriverError("Failed to make a temporary file at \(template): \(error)")
    }
    return String(cString: copy.baseAddress!)
  }
  return URL(fileURLWithPath: result)
}

func pluginSubcommand(subcommand: String, argv0: String, arguments: [String]) async throws {
  let scratchPath = URL(fileURLWithPath: ".build/carton")
  if FileManager.default.fileExists(atPath: scratchPath.path) {
    try FileManager.default.createDirectory(at: scratchPath, withIntermediateDirectories: true)
  }

  let terminal = InteractiveWriter.stdout
  let toolchainSystem = try ToolchainSystem(fileSystem: localFileSystem)
  let (swiftPath, _) = try await toolchainSystem.inferSwiftPath(terminal)
  let extraArguments = arguments

  let swiftExec = URL(fileURLWithPath: swiftPath.pathString)
  let pluginArguments = try derivePackageCommandArguments(
    swiftExec: swiftExec,
    subcommand: subcommand,
    scratchPath: scratchPath.path,
    extraArguments: extraArguments
  )

  try Foundation.Process.checkRun(swiftExec, arguments: pluginArguments, forwardExit: true)
}

public func main(arguments: [String]) async throws {
  let argv0 = arguments[0]
  let arguments = arguments.dropFirst()
  let pluginSubcommands = ["bundle", "dev", "test"]
  let subcommands = pluginSubcommands + ["package", "--version"]
  guard let subcommand = arguments.first, subcommands.contains(subcommand) else {
    if arguments.first == "init" {
      print(
        "Warning: 'init' subcommand has been removed, use 'swift package init' and add 'carton' as a dependency in Package.swift instead."
      )
    }
    print("Usage: swift run carton <subcommand> [options]")
    print("Available subcommands: \(subcommands.joined(separator: ", "))")
    exit(1)
  }

  switch subcommand {
  case _ where pluginSubcommands.contains(subcommand):
    try await pluginSubcommand(
      subcommand: subcommand, argv0: argv0, arguments: Array(arguments.dropFirst()))
  case "package":
    let terminal = InteractiveWriter.stdout
    let toolchainSystem = try ToolchainSystem(fileSystem: localFileSystem)
    let (swiftPath, _) = try await toolchainSystem.inferSwiftPath(terminal)
    try Foundation.Process.checkRun(
      URL(fileURLWithPath: swiftPath.pathString),
      arguments: ["package"] + arguments.dropFirst(), forwardExit: true
    )
  case "--version":
    print(cartonVersion)
  default: fatalError("Unimplemented subcommand!?")
  }
}
