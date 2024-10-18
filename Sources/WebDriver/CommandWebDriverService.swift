import CartonHelpers
import Foundation
import FlyingSocks

public struct CommandWebDriverService: WebDriverService {
  private static func findAvailablePort() throws -> (address: String, port: UInt16) {
    let address = try sockaddr_in.inet(ip4: "127.0.0.1", port: 0)
    let socket = try Socket(domain: Int32(sockaddr_in.family))
    do {
      try socket.bind(to: address)
    } catch {
      try socket.close()
      throw error
    }
    do {
      guard case let .ip4(address, port) = try socket.sockname() else {
        fatalError("Non-ip4 address!?")
      }
      try socket.close()
      return (address, port)
    } catch {
      try socket.close()
      throw error
    }
  }

  private static func launchDriver(
    terminal: InteractiveWriter,
    executablePath: String
  ) async throws -> (URL, CartonHelpers.Process) {
    let (address, port) = try findAvailablePort()
    let process = CartonHelpers.Process(arguments: [
      executablePath, "--port=\(port)",
    ])
    terminal.logLookup("Launch WebDriver executable: ", executablePath)
    try process.launch()
    let url = URL(string: "http://\(address):\(port)")!
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
