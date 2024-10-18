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

import CartonCore
import CartonHelpers
import Foundation
import Logging
import FlyingFox
import FlyingSocks

public struct BuilderProtocolSimpleBuildFailedError: Error {
  public init() {}
}

/// A protocol for a builder that can be used to build the app.
public protocol BuilderProtocol {
  var pathsToWatch: [AbsolutePath] { get }
  func run() async throws
}

public actor Server {
  public enum Error: Swift.Error & CustomStringConvertible {
    case invalidURL(String)
    case noOpenBrowserPlatform

    public var description: String {
      switch self {
      case .invalidURL(let string): "Invalid URL: \(string)"
      case .noOpenBrowserPlatform: "This platform cannot launch a browser."
      }
    }
  }

  typealias Channel = AsyncStream<WSMessage>.Continuation
  final class Connection: Hashable, Sendable {
    let channel: AsyncStream<WSMessage>.Continuation

    init(channel: Channel) {
      self.channel = channel
    }

    func close() {
      channel.finish()
    }

    func reload(_ text: String = "reload") {
      channel.yield(.text(text))
    }

    static func == (lhs: Connection, rhs: Connection) -> Bool {
      lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(self))
    }
  }

  public static let serverName = "carton dev server"

  public struct ServerNameField: CustomStringConvertible {
    public init(
      name: String = serverName,
      version: String = cartonVersion,
      pid: Int32
    ) {
      self.name = name
      self.version = version
      self.pid = pid
    }
    
    public var name: String
    public var version: String
    public var pid: Int32

    public var description: String {
      "\(name)/\(version) (PID \(pid))"
    }

    private static let regex = #/([\w ]+)/([\w\.]+) \(PID (\d+)\)/#

    public static func parse(_ string: String) throws -> ServerNameField {
      guard let m = try regex.wholeMatch(in: string),
            let pid = Int32(m.output.3) else {
        throw CartonCoreError("invalid server name: \(string)")
      }

      let name = String(m.output.1)
      let version = String(m.output.2)
      return ServerNameField(name: name, version: version, pid: pid)
    }
  }


  /// A set of connected WebSocket clients currently connected to this server.
  private var connections = Set<Connection>()

  /// Filesystem watcher monitoring relevant source files for changes.
  private var watcher: FSWatch?

  private let server: HTTPServer
  private var serverTask: Task<Void, any Swift.Error>?

  /// Local URL of this server, `https://127.0.0.1:8080/` by default.
  private let localURL: URL

  /// Whether a build that could be triggered by this server is currently running.
  private var isBuildCurrentlyRunning = false

  /// Whether a subsequent build is currently scheduled on top of a currently running build.
  private var isSubsequentBuildScheduled = false

  /// Continuation for waitUntilTestFinished, passing `hadError: Bool`
  private var onTestFinishedContinuation: CheckedContinuation<Bool, Never>?

  let configuration: Configuration

  let serverName: ServerNameField

  public struct Configuration {
    let builder: BuilderProtocol?
    let mainWasmPath: AbsolutePath
    let verbose: Bool
    let bindingAddress: String
    let port: Int
    let host: String
    /// Environment variables to be passed to the test process.
    let env: [String: String]?
    let customIndexPath: AbsolutePath?
    let resourcesPaths: [String]
    let entrypoint: Entrypoint
    let pid: Int32?
    let terminal: InteractiveWriter

    public init(
      builder: BuilderProtocol?,
      mainWasmPath: AbsolutePath,
      verbose: Bool,
      bindingAddress: String,
      port: Int,
      host: String,
      env: [String: String]? = nil,
      customIndexPath: AbsolutePath?,
      resourcesPaths: [String],
      entrypoint: Entrypoint,
      pid: Int32?,
      terminal: InteractiveWriter
    ) {
      self.builder = builder
      self.mainWasmPath = mainWasmPath
      self.verbose = verbose
      self.bindingAddress = bindingAddress
      self.port = port
      self.host = host
      self.env = env
      self.customIndexPath = customIndexPath
      self.resourcesPaths = resourcesPaths
      self.entrypoint = entrypoint
      self.pid = pid
      self.terminal = terminal
    }

    public static func host(bindOption: String, hostOption: String?) -> String {
      if let hostOption { return hostOption }
      if bindOption == "0.0.0.0" { return "127.0.0.1" }
      return bindOption
    }
  }

  public init(
    _ configuration: Configuration
  ) async throws {
    let localURLString = "http://\(configuration.host):\(configuration.port)/"
    guard let localURL = URL(string: localURLString) else {
      throw Error.invalidURL(localURLString)
    }
    self.localURL = localURL
    watcher = nil
    self.configuration = configuration
    self.serverName = ServerNameField(
      pid: configuration.pid ?? ProcessInfo.processInfo.processIdentifier
    )

    self.server = HTTPServer(
      address: try .inet(
        ip4: configuration.bindingAddress,
        port: UInt16(configuration.port)
      ),
      logger: PrintLogger(category: "org.swiftwasm.carton.dev-server")
    )

    try await addRoutes()

    guard let builder = configuration.builder else {
      return
    }

    if !builder.pathsToWatch.isEmpty {
      let terminal = configuration.terminal

      terminal.write("\nWatching these directories for changes:\n", inColor: .green)
      builder.pathsToWatch.forEach { terminal.logLookup("", $0) }
      terminal.write("\n")

      watcher = FSWatch(paths: builder.pathsToWatch, latency: 0.1) { [weak self] changes in
        guard let self = self, !changes.isEmpty else { return }
        Task { try await self.onChange(changes, configuration) }
      }
      try watcher?.start()
    }
  }

  private func addRoutes() async throws {
    await self.server.appendRoute("/") {
      try await self.respondIndexPage($0)
    }
    await self.server.appendRoute(
      "/main.wasm",
      to: FileHTTPHandler(path: configuration.mainWasmPath.asURL, contentType: "application/wasm")
    )
    await self.server.appendRoute("/process-info.json") {
      try await self.respondProcessInfo($0)
    }
    await self.server.appendRoute(HTTPRoute("/\(configuration.entrypoint.fileName)")) {
      try await self.respondEntrypoint($0, entrypoint: self.configuration.entrypoint)
    }
    let buildDirectory = configuration.mainWasmPath.parentDirectory
    for directoryName in try localFileSystem.resourcesDirectoryNames(relativeTo: buildDirectory) {
      let baseDir = URL(fileURLWithPath: buildDirectory.pathString).appendingPathComponent(
        directoryName
      )
      await self.server.appendRoute(
        HTTPRoute("/\(directoryName)/*"),
        to: AutoContentTypeHandler(
          handler: DirectoryHTTPHandler(
            root: baseDir,
            serverPath: directoryName
          )
        )
      )
    }

    await self.server.appendRoute("/watcher") { [weak self] request in
      guard let self else { return .init(statusCode: .badRequest) }
      return try await ServerWebSocketHandler(server: self).handleRequest(request)
    }

    // Serve resources for the main target at the root path.
    for mainResourcesPath in configuration.resourcesPaths {
      let baseDirectory = URL(fileURLWithPath: mainResourcesPath)
      await self.server.appendRoute(
        "/*", to: AutoContentTypeHandler(handler: DirectoryHTTPHandler(root: baseDirectory))
      )
    }
  }

  private func onChange(_ changes: [AbsolutePath], _ configuration: Configuration) async throws {
    guard !isBuildCurrentlyRunning else {
      if !isSubsequentBuildScheduled {
        isSubsequentBuildScheduled = true
      }
      return
    }

    configuration.terminal.write(
      "\nThese paths have changed, rebuilding...\n",
      inColor: .yellow
    )
    for change in changes.map(\.pathString) {
      configuration.terminal.write("- \(change)\n", inColor: .cyan)
    }

    isBuildCurrentlyRunning = true
    defer { isBuildCurrentlyRunning = false }

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
  }

  private func add(pendingChanges: [AbsolutePath]) {}

  func add(connection: Connection) {
    connections.insert(connection)
  }

  func remove(connection: Connection) {
    connections.remove(connection)
  }

  public func start() async throws -> URL {
    serverTask = Task { try await self.server.start() }
    return localURL
  }

  /// Wait and handle the shutdown
  public func waitUntilStop() async throws {
    try await self.serverTask?.value
    try closeSockets()
  }

  /// Wait and handle the shutdown
  public func waitUntilTestFinished() async throws -> Bool {
    let hadError = await withCheckedContinuation { cont in
      self.onTestFinishedContinuation = cont
    }
    self.onTestFinishedContinuation = nil
    try closeSockets()
    return hadError
  }

  func closeSockets() throws {
    for conn in connections {
      conn.close()
    }
  }

  private func run(
    _ builder: any BuilderProtocol,
    _ terminal: InteractiveWriter
  ) async throws {
    do {
      try await builder.run()
    } catch {
      terminal.write("Build failed\n", inColor: .red)
      switch error {
      case is BuilderProtocolSimpleBuildFailedError: break
      default:
        terminal.write("\(error)\n", inColor: .red)
      }
      return
    }

    terminal.write("Build completed successfully\n", inColor: .green)
    terminal.logLookup("The app is currently hosted at ", localURL)
    connections.forEach { $0.reload() }
  }

  func stopTest(hadError: Bool) {
    self.onTestFinishedContinuation?.resume(returning: hadError)
  }
}

/// Attempts to open the specified URL string in system browser on macOS and Linux.
public func openInSystemBrowser(url: URL) throws {
  #if os(macOS)
    let openCommand = "open"
  #elseif os(Linux)
    let openCommand = "xdg-open"
  #else
    throw Server.Error.noOpenBrowserPlatform
  #endif
  let process = Process(
    arguments: [openCommand, url.absoluteString],
    outputRedirection: .none,
    startNewProcessGroup: true
  )
  try process.launch()
}
