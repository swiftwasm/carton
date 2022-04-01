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
import PackageModel
import SwiftToolchain
import TSCBasic
import TSCUtility
import Vapor

private enum Event {
  enum CodingKeys: String, CodingKey {
    case kind
    case stackTrace
    case testRunOutput
  }

  enum Kind: String, Decodable {
    case stackTrace
    case testRunOutput
  }

  case stackTrace(String)
  case testRunOutput(String)
}

extension Event: Decodable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let kind = try container.decode(Kind.self, forKey: .kind)

    switch kind {
    case .stackTrace:
      let rawStackTrace = try container.decode(String.self, forKey: .stackTrace)
      self = .stackTrace(rawStackTrace)
    case .testRunOutput:
      let output = try container.decode(String.self, forKey: .testRunOutput)
      self = .testRunOutput(output)
    }
  }
}

/// This `Hashable` conformance is required to handle simultaneous connections with `Set<WebSocket>`
extension WebSocket: Hashable {
  public static func == (lhs: WebSocket, rhs: WebSocket) -> Bool {
    lhs === rhs
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

public actor Server {
  /// Used for decoding `Event` values sent from the WebSocket client.
  private let decoder = JSONDecoder()

  /// A set of connected WebSocket clients currently connected to this server.
  private var connections = Set<WebSocket>()

  /// Filesystem watcher monitoring relevant source files for changes.
  private var watcher: FSWatch?

  /// An instance of Vapor server application.
  private let app: Application

  /// Local URL of this server, `https://128.0.0.1:8080/` by default.
  private let localURL: String

  /// Whether a browser tab should automatically open as soon as the server is ready.
  private let shouldSkipAutoOpen: Bool

  /// Whether a build that could be triggered by this server is currently running.
  private var isBuildCurrentlyRunning = false

  /// Whether a subsequent build is currently scheduled on top of a currently running build.
  private var isSubsequentBuildScheduled = false

  public struct Configuration {
    let builder: Builder?
    let mainWasmPath: AbsolutePath
    let verbose: Bool
    let shouldSkipAutoOpen: Bool
    let port: Int
    let host: String
    let customIndexContent: String?
    let manifest: Manifest
    let product: ProductDescription?
    let entrypoint: Entrypoint
    let terminal: InteractiveWriter

    public init(
      builder: Builder?,
      mainWasmPath: AbsolutePath,
      verbose: Bool,
      shouldSkipAutoOpen: Bool,
      port: Int,
      host: String,
      customIndexContent: String?,
      manifest: Manifest,
      product: ProductDescription?,
      entrypoint: Entrypoint,
      terminal: InteractiveWriter
    ) {
      self.builder = builder
      self.mainWasmPath = mainWasmPath
      self.verbose = verbose
      self.shouldSkipAutoOpen = shouldSkipAutoOpen
      self.port = port
      self.host = host
      self.customIndexContent = customIndexContent
      self.manifest = manifest
      self.product = product
      self.entrypoint = entrypoint
      self.terminal = terminal
    }
  }

  public init(
    _ configuration: Configuration
  ) async throws {
    var env = Environment(
      name: configuration.verbose ? "development" : "production",
      arguments: ["vapor"]
    )
    localURL = "http://\(configuration.host):\(configuration.port)/"
    shouldSkipAutoOpen = configuration.shouldSkipAutoOpen

    try LoggingSystem.bootstrap(from: &env)
    app = Application(env)
    watcher = nil

    app.configure(
      .init(
        port: configuration.port,
        host: configuration.host,
        mainWasmPath: configuration.mainWasmPath,
        customIndexContent: configuration.customIndexContent,
        manifest: configuration.manifest,
        product: configuration.product,
        entrypoint: configuration.entrypoint,
        onWebSocketOpen: { [weak self] ws, environment in
          if let handler = await self?.createWSHandler(
            configuration,
            in: environment,
            terminal: configuration.terminal
          ) {
            ws.onText(handler)
          }

          await self?.add(connection: ws)
        },
        onWebSocketClose: { [weak self] in await self?.remove(connection: $0) }
      )
    )
    // Listen to Vapor App lifecycle events
    app.lifecycle.use(self)

    guard let builder = configuration.builder else {
      return
    }

    if !builder.pathsToWatch.isEmpty {
      watcher = FSWatch(paths: builder.pathsToWatch, latency: 0.1) { [weak self] changes in
        guard let self = self, !changes.isEmpty else { return }
        Task { try await self.onChange(changes, configuration) }
      }
      try watcher?.start()
    }
  }

  private func onChange(_ changes: [AbsolutePath], _ configuration: Configuration) async throws {
    guard !isBuildCurrentlyRunning else {
      if !isSubsequentBuildScheduled {
        isSubsequentBuildScheduled = true
      }
      return
    }

    if !configuration.verbose {
      configuration.terminal.clearWindow()
    }
    configuration.terminal.write(
      "\nThese paths have changed, rebuilding...\n",
      inColor: .yellow
    )
    for change in changes.map(\.pathString) {
      configuration.terminal.write("- \(change)\n", inColor: .cyan)
    }

    isBuildCurrentlyRunning = true
    // `configuration.builder` is guaranteed to be non-nil here as its presence is checked in `init`
    try await run(configuration.builder!, configuration.terminal)

    if isSubsequentBuildScheduled {
      configuration.terminal.write(
        "\nMore paths have changed during the build, rebuilding again...\n",
        inColor: .yellow
      )
      try await run(configuration.builder!, configuration.terminal)
    }

    isSubsequentBuildScheduled = false
    isBuildCurrentlyRunning = false
  }

  private func add(pendingChanges: [AbsolutePath]) {}

  private func add(connection: WebSocket) {
    connections.insert(connection)
  }

  private func remove(connection: WebSocket) {
    connections.remove(connection)
  }

  /// Blocking function that starts the HTTP server.
  public nonisolated func run() async throws {
    // Explicitly hop to another thread to avoid blocking the thread that is running the actor executor
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      Thread {
        Task {
          do {
            defer { self.app.shutdown() }
            try self.app.run()
            try await self.closeSockets()
            continuation.resume()
          } catch {
            continuation.resume(with: .failure(error))
          }
        }
      }
      .start()
    }
  }

  func closeSockets() throws {
    for conn in connections {
      try conn.close().wait()
    }
  }

  private func run(
    _ builder: Builder,
    _ terminal: InteractiveWriter
  ) async throws {
    try await builder.run()

    terminal.write("\nBuild completed successfully\n", inColor: .green, bold: false)
    terminal.logLookup("The app is currently hosted at ", localURL)
    connections.forEach { $0.send("reload") }
  }
}

extension Server {
  /// Returns a handler that responds to WebSocket messages coming from the browser.
  func createWSHandler(
    _ configuration: Configuration,
    in environment: DestinationEnvironment,
    terminal: InteractiveWriter
  ) -> (WebSocket, String) -> () {
    { [weak self] _, text in
      guard
        let data = text.data(using: .utf8),
        let event = try? self?.decoder.decode(Event.self, from: data)
      else {
        return
      }

      switch event {
      case let .stackTrace(rawStackTrace):
        if let stackTrace = rawStackTrace.parsedStackTrace(in: environment) {
          terminal.write("\nAn error occurred, here's a stack trace for it:\n", inColor: .red)
          stackTrace.forEach { item in
            terminal.write("  \(item.symbol)", inColor: .cyan)
            terminal.write(" at \(item.location ?? "<unknown>")\n", inColor: .gray)
          }
        } else {
          terminal.write("\nAn error occurred, here's the raw stack trace for it:\n", inColor: .red)
          terminal.write("  Please create an issue or PR to the Carton repository\n" +
            "  with your browser name and this raw stack trace so\n" +
            "  we can add support for it: https://github.com/swiftwasm/carton\n", inColor: .gray)
          terminal.write(rawStackTrace + "\n")
        }

      case let .testRunOutput(output):
        TestsParser().parse(output, terminal)

        // Test run finished, no need to keep the server running anymore.
        if configuration.builder == nil {
          kill(getpid(), SIGINT)
        }
      }
    }
  }
}

extension Server: LifecycleHandler {
  public nonisolated func didBoot(_ application: Application) throws {
    guard !shouldSkipAutoOpen else { return }
    openInSystemBrowser(url: localURL)
  }

  /// Attempts to open the specified URL string in system browser on macOS and Linux.
  /// - Returns: true if launching command returns successfully.
  @discardableResult
  private nonisolated func openInSystemBrowser(url: String) -> Bool {
    #if os(macOS)
    let openCommand = "open"
    #elseif os(Linux)
    let openCommand = "xdg-open"
    #else
    return false
    #endif
    let process = Process(
      arguments: [openCommand, url],
      outputRedirection: .none,
      verbose: false,
      startNewProcessGroup: true
    )
    do {
      try process.launch()
      return true
    } catch {
      return false
    }
  }
}
