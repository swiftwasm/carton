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
import CartonHelpers
import CartonKit
import Foundation

struct Dev: AsyncParsableCommand {
  enum Error: Swift.Error & CustomStringConvertible {
    case noBuildRequestOption
    case noBuildResponseOption
    case failedToOpenBuildRequestPipe
    case failedToOpenBuildResponsePipe

    var description: String {
      switch self {
      case .noBuildRequestOption: "--build-request option is necessary if you want to watch, but has not been specified."
      case .noBuildResponseOption: "--build-response option is necessary if you want to watch, but has not been specified."
      case .failedToOpenBuildRequestPipe: "failed to open build request pipe"
      case .failedToOpenBuildResponsePipe: "failed to open build response pipe"
      }
    }
  }

  static let entrypoint = Entrypoint(fileName: "dev.js", content: StaticResource.dev)

  @Option(help: "Specify name of an executable product in development.")
  var product: String?

  @Option(help: "Specify a path to a custom `index.html` file to be used for your app.")
  var customIndexPage: String?

  @Flag(help: "When specified, build in the release mode.")
  var release = false

  @Option(help: "Turn on runtime checks for various behavior.")
  private var sanitize: SanitizeVariant?

  @Flag(name: .shortAndLong, help: "Don't clear terminal window after files change.")
  var verbose = false

  @Option(name: .shortAndLong, help: "Set the HTTP port the development server will run on.")
  var port = 8080

  @Option(
    name: .shortAndLong,
    help: "Set the location where the development server will run. Default is `127.0.0.1`."
  )
  var host = "127.0.0.1"

  @Flag(name: .long, help: "Skip automatically opening app in system browser.")
  var skipAutoOpen = false

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

  static let configuration = CommandConfiguration(
    abstract: "Watch the current directory, host the app, rebuild on change."
  )

  private func makeBuilderIfNeed() throws -> SwiftPMPluginBuilder? {
    guard !watchPaths.isEmpty else {
      return nil
    }

    guard let buildRequest else {
      throw Error.noBuildRequestOption
    }
    guard let buildResponse else {
      throw Error.noBuildResponseOption
    }

    let pathsToWatch = try watchPaths.map {
      try AbsolutePath(validating: $0, relativeTo: localFileSystem.currentWorkingDirectory!)
    }

    guard let buildRequest = FileHandle(forWritingAtPath: buildRequest) else {
      throw Error.failedToOpenBuildRequestPipe
    }
    guard let buildResponse = FileHandle(forReadingAtPath: buildResponse) else {
      throw Error.failedToOpenBuildResponsePipe
    }

    return SwiftPMPluginBuilder(
      pathsToWatch: pathsToWatch,
      buildRequest: buildRequest,
      buildResponse: buildResponse
    )
  }

  func run() async throws {
    let terminal = InteractiveWriter.stdout

    if !verbose {
      terminal.revertCursorAndClear()
    }

    let server = try await Server(
      .init(
        builder: try makeBuilderIfNeed(),
        mainWasmPath: AbsolutePath(
          validating: mainWasmPath, relativeTo: localFileSystem.currentWorkingDirectory!),
        verbose: verbose,
        port: port,
        host: host,
        customIndexPath: customIndexPage.map {
          try AbsolutePath(validating: $0, relativeTo: localFileSystem.currentWorkingDirectory!)
        },
        resourcesPaths: resources,
        entrypoint: Self.entrypoint,
        terminal: terminal
      )
    )
    let localURL = try await server.start()
    if !skipAutoOpen {
      openInSystemBrowser(url: localURL)
    }
    try await server.waitUntilStop()
  }
}

/// Builder for communicating with the SwiftPM Plugin process by IPC.
struct SwiftPMPluginBuilder: BuilderProtocol {
  let pathsToWatch: [AbsolutePath]
  let buildRequest: FileHandle
  let buildResponse: FileHandle

  init(pathsToWatch: [AbsolutePath], buildRequest: FileHandle, buildResponse: FileHandle) {
    self.pathsToWatch = pathsToWatch
    self.buildRequest = buildRequest
    self.buildResponse = buildResponse
  }

  func run() async throws {
    // We expect single response per request
    try buildRequest.write(contentsOf: Data([1]))
    _ = try buildResponse.read(upToCount: 1)
  }
}
