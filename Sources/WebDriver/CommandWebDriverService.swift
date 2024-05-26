import CartonHelpers
import Foundation
import NIOCore
import NIOPosix

public struct CommandWebDriverService: WebDriverService {
  private static func findAvailablePort() async throws -> SocketAddress {
    let bootstrap = ServerBootstrap(group: .singletonMultiThreadedEventLoopGroup)
    let address = try SocketAddress.makeAddressResolvingHost("127.0.0.1", port: 0)
    let channel = try await bootstrap.bind(to: address).get()
    let localAddr = channel.localAddress!
    try await channel.close()
    return localAddr
  }

  private static func launchDriver(
    terminal: InteractiveWriter,
    executablePath: String
  ) async throws -> (URL, CartonHelpers.Process) {
    let address = try await findAvailablePort()
    let process = CartonHelpers.Process(arguments: [
      executablePath, "--port=\(address.port!)",
    ])
    terminal.logLookup("Launch WebDriver executable: ", executablePath)
    try process.launch()
    let url = URL(string: "http://\(address.ipAddress!):\(address.port!)")!
    return (url, process)
  }

  public static func findFromEnvironment(
    terminal: CartonHelpers.InteractiveWriter
  ) async throws -> CommandWebDriverService? {
    terminal.logLookup("- checking WebDriver executable: ", "WEBDRIVER_PATH")
    guard let executable = ProcessInfo.processInfo.environment["WEBDRIVER_PATH"] else {
      return nil
    }
    let (endpoint, process) = try await launchDriver(
      terminal: terminal, executablePath: executable
    )
    return CommandWebDriverService(endpoint: endpoint, process: process)
  }

  public static func findFromPath(
    terminal: CartonHelpers.InteractiveWriter
  ) async throws -> CommandWebDriverService? {
    let driverCandidates = [
      "chromedriver", "geckodriver", "safaridriver", "msedgedriver",
    ]
    terminal.logLookup(
      "- checking WebDriver executable in PATH: ", driverCandidates.joined(separator: ", "))
    guard let found = driverCandidates.lazy
      .compactMap({ CartonHelpers.Process.findExecutable($0) }).first else
    {
      return nil
    }
    let (endpoint, process) = try await launchDriver(
      terminal: terminal, executablePath: found.pathString
    )
    return CommandWebDriverService(endpoint: endpoint, process: process)
  }

  public static func find(
    terminal: CartonHelpers.InteractiveWriter
  ) async throws -> CommandWebDriverService? {
    if let driver = try await findFromEnvironment(terminal: terminal) {
      return driver
    }

    if let driver = try await findFromPath(terminal: terminal) {
      return driver
    }

    return nil
  }
  
  public init(
    endpoint: URL,
    process: CartonHelpers.Process
  ) {
    self.endpoint = endpoint
    self.process = process
  }

  public var endpoint: URL
  public var process: CartonHelpers.Process

  public func dispose() {
    process.signal(SIGKILL)
  }
}
