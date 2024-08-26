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
import NIO
import NIOHTTP1
import NIOWebSocket

private enum Event {
  enum CodingKeys: String, CodingKey {
    case kind
    case stackTrace
    case testRunOutput
    case errorReport
  }

  enum Kind: String, Decodable {
    case stackTrace
    case testRunOutput
    case testPassed
    case errorReport
  }

  case stackTrace(String)
  case testRunOutput(String)
  case testPassed
  case errorReport(String)
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
    case .testPassed:
      self = .testPassed
    case .errorReport:
      let output = try container.decode(String.self, forKey: .errorReport)
      self = .errorReport(output)
    }
  }
}

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

  final class Connection: Hashable {
    let channel: Channel

    init(channel: Channel) {
      self.channel = channel
    }

    func close() -> EventLoopFuture<Void> {
      channel.eventLoop.makeSucceededVoidFuture()
    }

    func reload(_ text: String = "reload") {
      let buffer = channel.allocator.buffer(string: text)
      let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
      self.channel.writeAndFlush(frame, promise: nil)
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

  /// Used for decoding `Event` values sent from the WebSocket client.
  private let decoder = JSONDecoder()

  /// A set of connected WebSocket clients currently connected to this server.
  private var connections = Set<Connection>()

  /// Filesystem watcher monitoring relevant source files for changes.
  private var watcher: FSWatch?

  private var serverChannel: (any Channel)!

  /// Local URL of this server, `https://127.0.0.1:8080/` by default.
  private let localURL: URL

  /// Whether a build that could be triggered by this server is currently running.
  private var isBuildCurrentlyRunning = false

  /// Whether a subsequent build is currently scheduled on top of a currently running build.
  private var isSubsequentBuildScheduled = false

  /// Continuation for waitUntilTestFinished, passing `hadError: Bool`
  private var onTestFinishedContinuation: CheckedContinuation<Bool, Never>?

  private let configuration: Configuration

  private let serverName: ServerNameField

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

  private func add(connection: Connection) {
    connections.insert(connection)
  }

  private func remove(connection: Connection) {
    connections.remove(connection)
  }

  public func start() async throws -> URL {
    let group = MultiThreadedEventLoopGroup.singleton
    let upgrader = NIOWebSocketServerUpgrader(
      maxFrameSize: Int(UInt32.max),
      shouldUpgrade: {
        (channel: Channel, head: HTTPRequestHead) in
        channel.eventLoop.makeSucceededFuture(HTTPHeaders())
      },
      upgradePipelineHandler: { (channel: Channel, head: HTTPRequestHead) in
        return channel.eventLoop.makeFutureWithTask { () -> ServerWebSocketHandler? in
          guard head.uri == "/watcher" else {
            return nil
          }
          let environment =
            head.headers["User-Agent"].compactMap(DestinationEnvironment.init).first
            ?? .other
          let handler = ServerWebSocketHandler(
            configuration: ServerWebSocketHandler.Configuration(
              onText: { [weak self] (text) in
                self?.webSocketTextHandler(text: text, environment: environment)
              },
              onBinary: { [weak self] (data) in
                self?.webSocketBinaryHandler(data: data)
              }
            )
          )
          await self.add(connection: Connection(channel: channel))
          return handler
        }.flatMap { maybeHandler in
          guard let handler = maybeHandler else {
            return channel.eventLoop.makeSucceededVoidFuture()
          }
          let aggregator = NIOWebSocketFrameAggregator(
            minNonFinalFragmentSize: 0,
            maxAccumulatedFrameCount: .max,
            maxAccumulatedFrameSize: .max
          )
          return channel.pipeline.addHandlers(aggregator, handler)
        }
      }
    )
    let handlerConfiguration = ServerHTTPHandler.Configuration(
      logger: Logger(label: "org.swiftwasm.carton.dev-server"),
      mainWasmPath: configuration.mainWasmPath,
      customIndexPath: configuration.customIndexPath,
      resourcesPaths: configuration.resourcesPaths,
      entrypoint: configuration.entrypoint,
      serverName: serverName.description,
      env: configuration.env
    )
    let channel = try await ServerBootstrap(group: group)
      // Specify backlog and enable SO_REUSEADDR for the server itself
      .serverChannelOption(ChannelOptions.backlog, value: 256)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .childChannelInitializer { channel in
        let httpHandler = ServerHTTPHandler(configuration: handlerConfiguration)
        let config: NIOHTTPServerUpgradeConfiguration = (
          upgraders: [upgrader],
          completionHandler: { _ in
            channel.pipeline.removeHandler(httpHandler, promise: nil)
          }
        )
        return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: config).flatMap {
          channel.pipeline.addHandler(httpHandler)
        }
      }
      // Enable SO_REUSEADDR for the accepted Channels
      .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .bind(host: configuration.bindingAddress, port: configuration.port)
      .get()

    self.serverChannel = channel
    return localURL
  }

  /// Wait and handle the shutdown
  public func waitUntilStop() async throws {
    try await self.serverChannel.closeFuture.get()
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
      try conn.close().wait()
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

  private func stopTest(hadError: Bool) {
    self.onTestFinishedContinuation?.resume(returning: hadError)
  }
}

extension Server {
  /// Respond to WebSocket messages coming from the browser.
  nonisolated func webSocketTextHandler(
    text: String,
    environment: DestinationEnvironment
  ) {
    guard
      let data = text.data(using: .utf8),
      let event = try? self.decoder.decode(Event.self, from: data)
    else {
      return
    }

    let terminal = self.configuration.terminal

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
        terminal.write(
          "  Please create an issue or PR to the Carton repository\n"
          + "  with your browser name and this raw stack trace so\n"
          + "  we can add support for it: https://github.com/swiftwasm/carton\n", inColor: .gray
        )
        terminal.write(rawStackTrace + "\n")
      }

    case let .testRunOutput(output):
      TestsParser().parse(output, terminal)

    case .testPassed:
      Task { await self.stopTest(hadError: false) }

    case let .errorReport(output):
      terminal.write("\nAn error occurred:\n", inColor: .red)
      terminal.write(output + "\n")

      Task { await self.stopTest(hadError: true) }
    }
  }

  private static func decodeLines(data: Data) -> [String] {
    let text = String(decoding: data, as: UTF8.self)
    return text.components(separatedBy: .newlines)
  }

  nonisolated func webSocketBinaryHandler(data: Data) {
    let terminal = self.configuration.terminal

    if data.count < 2 {
      return
    }

    var kind: UInt16 = 0
    _ = withUnsafeMutableBytes(of: &kind) { (buffer) in
      data.copyBytes(to: buffer, from: 0..<2)
    }
    kind = UInt16(littleEndian: kind)

    switch kind {
    case 1001:
      // stdout
      let chunk = data.subdata(in: 2..<data.count)
      if chunk.isEmpty { return }

      for line in Self.decodeLines(data: chunk) {
        terminal.write("stdout: " + line + "\n")
      }
    case 1002:
      // stderr
      let chunk = data.subdata(in: 2..<data.count)
      if chunk.isEmpty { return }

      for line in Self.decodeLines(data: chunk) {
        terminal.write("stderr: " + line + "\n", inColor: .red)
      }
    default: break
    }
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
