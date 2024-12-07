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
import CartonCore
import CartonHelpers
import Foundation

enum DevCommandError: Error & CustomStringConvertible {
  case noBuildRequestOption
  case noBuildResponseOption
  case failedToOpenBuildRequestPipe
  case failedToOpenBuildResponsePipe
  case pluginConnectionClosed
  case brokenPluginResponse

  var description: String {
    switch self {
    case .noBuildRequestOption:
      "--build-request option is necessary if you want to watch, but has not been specified."
    case .noBuildResponseOption:
      "--build-response option is necessary if you want to watch, but has not been specified."
    case .failedToOpenBuildRequestPipe: "failed to open build request pipe."
    case .failedToOpenBuildResponsePipe: "failed to open build response pipe."
    case .pluginConnectionClosed: "connection with the plugin has been closed."
    case .brokenPluginResponse: "response from the plugin was broken."
    }
  }
}

struct CartonFrontendDevCommand: AsyncParsableCommand {

  @Option(help: "Specify name of an executable product in development.")
  var product: String?

  @Option(help: "Specify a path to a custom `index.html` file to be used for your app.")
  var customIndexPage: String?

  @Flag(help: "When specified, build in the release mode.")
  var release = false

  @Flag(name: .shortAndLong, help: "Don't clear terminal window after files change.")
  var verbose = false

  @Option(
    name: .shortAndLong,
    help: """
      Set the address where the development server will listen for connections.
      """
  )
  var bind: String = "0.0.0.0"

  @Option(name: .shortAndLong, help: "Set the HTTP port the development server will run on.")
  var port = 8080

  @Option(
    name: .shortAndLong,
    help: """
      Set the location where the development server will run.
      The default value is derived from the –-bind option.
      """
  )
  var host: String?

  @Option(
    name: .customLong("watch-path"),
    help: "Specify a path to a directory to watch for changes."
  )
  var watchPaths: [String] = []

  @Option(
    name: .long,
    help: ArgumentHelp(
      "Internal: Path to resources directory built by the SwiftPM Plugin process.",
      visibility: .private
    )
  )
  var resources: [String] = []

  @Option(
    help: ArgumentHelp(
      "Internal: Path to the named pipe used to send build requests to the SwiftPM Plugin process.",
      visibility: .private
    )
  )
  var buildRequest: String?

  @Option(
    help: ArgumentHelp(
      "Internal: Path to the named pipe used to receive build responses from the SwiftPM Plugin process.",
      visibility: .private
    )
  )
  var buildResponse: String?

  @Option(
    help: ArgumentHelp(
      "Internal: Path to the main WebAssembly file built by the SwiftPM Plugin process.",
      visibility: .private
    )
  )
  var mainWasmPath: String

  @Option(name: .long, help: .hidden) var pid: Int32?

  @Option(
    name: .long,
    help: ArgumentHelp(
      "Internal: Path to writable directory", visibility: .private
    ))
  var pluginWorkDirectory: String = "./"

  static let configuration = CommandConfiguration(
    commandName: "dev",
    abstract: "Watch the current directory, host the app, rebuild on change."
  )

  func run() async throws {
    let terminal = InteractiveWriter.stdout

    if !verbose {
      terminal.revertCursorAndClear()
    }

    let cwd = localFileSystem.currentWorkingDirectory!
    let mainWasmPath = try AbsolutePath(validating: mainWasmPath, relativeTo: cwd)
    let bundleDirectory = try AbsolutePath(
      validating: pluginWorkDirectory,
      relativeTo: cwd
    ).appending(component: "Bundle")

    let layout = BundleLayout(
      mainModuleBaseName: mainWasmPath.basenameWithoutExt,
      wasmSourcePath: mainWasmPath,
      buildDirectory: mainWasmPath.parentDirectory,
      bundleDirectory: bundleDirectory,
      topLevelResourcePaths: resources
    )
    try build(layout: layout, terminal: terminal)

    try Foundation.Process.checkRun(Foundation.Process.which("npm"), arguments: [
      "--prefix", bundleDirectory.pathString, "install",
    ])

    try watch(cwd: cwd, layout: layout, terminal: terminal)

    var viteArguments = [bundleDirectory.pathString, "--clearScreen", "false"]
    if let host = host {
      viteArguments += ["--host", host]
    }
    viteArguments += ["--port", "\(port)"]
    let viteProcess = Foundation.Process()
    viteProcess.executableURL = bundleDirectory.asURL
      .appendingPathComponent("node_modules")
      .appendingPathComponent(".bin")
      .appendingPathComponent("vite")
    viteProcess.arguments = viteArguments
    let signalSources = viteProcess.forwardTerminationSignals()
    defer {
      for signalSource in signalSources {
        signalSource.cancel()
      }
    }
    try viteProcess.run()

    let _: () = try await withCheckedThrowingContinuation { continuation in
      viteProcess.terminationHandler = { process in
        if process.terminationStatus != 0 {
          continuation.resume(
            throwing: CartonCoreError("Vite process exited with status \(process.terminationStatus)")
          )
        } else {
          continuation.resume()
        }
      }
    }
  }

  private func build(layout: BundleLayout, terminal: InteractiveWriter) throws {
    try localFileSystem.createDirectory(layout.bundleDirectory, recursive: false)

    try layout.copyAppEntrypoint(
      customIndexPage: customIndexPage,
      contentHash: false,
      terminal: terminal
    )
  }

  private func watch(cwd: AbsolutePath, layout: BundleLayout, terminal: InteractiveWriter) throws {
    guard !watchPaths.isEmpty else {
      return
    }

    let pathsToWatch = try watchPaths.map {
      try AbsolutePath(validating: $0, relativeTo: cwd)
    }
    guard let buildRequest else {
      throw DevCommandError.noBuildRequestOption
    }
    guard let buildResponse else {
      throw DevCommandError.noBuildResponseOption
    }
    guard let buildRequest = FileHandle(forWritingAtPath: buildRequest) else {
      throw DevCommandError.failedToOpenBuildRequestPipe
    }
    guard let buildResponse = FileHandle(forReadingAtPath: buildResponse) else {
      throw DevCommandError.failedToOpenBuildResponsePipe
    }

    let builder = SwiftPMPluginBuilder(
      pathsToWatch: pathsToWatch,
      buildRequest: buildRequest,
      buildResponse: buildResponse
    )

    let watcher = FSWatch(
      paths: pathsToWatch,
      latency: 0.1
    ) { changes in
      guard !changes.isEmpty else { return }
      do {
        try builder.run()
        try build(layout: layout, terminal: terminal)
      } catch {
        terminal.write("\(error)", inColor: .red)
      }
    }
    try watcher.start()
  }
}

/// Builder for communicating with the SwiftPM Plugin process by IPC.
struct SwiftPMPluginBuilder {
  struct BuilderProtocolSimpleBuildFailedError: Error {}
  let pathsToWatch: [AbsolutePath]
  let buildRequest: FileHandle
  let buildResponse: FileHandle

  init(pathsToWatch: [AbsolutePath], buildRequest: FileHandle, buildResponse: FileHandle) {
    self.pathsToWatch = pathsToWatch
    self.buildRequest = buildRequest
    self.buildResponse = buildResponse
  }

  func run() throws {
    // We expect single response per request
    try buildRequest.write(contentsOf: Data([1]))
    guard let responseMessage = try buildResponse.read(upToCount: 1) else {
      throw DevCommandError.pluginConnectionClosed
    }
    if responseMessage.count < 1 {
      throw DevCommandError.brokenPluginResponse
    }
    switch responseMessage[0] {
    case 0:
      throw BuilderProtocolSimpleBuildFailedError()
    case 1:
      // build succeeded
      return
    default:
      throw DevCommandError.brokenPluginResponse
    }
  }
}
