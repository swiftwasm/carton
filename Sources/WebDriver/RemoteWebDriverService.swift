import CartonCore
import Foundation

public struct RemoteWebDriverService: WebDriverService {
  public static func find(
    terminal: InteractiveWriter
  ) async throws -> RemoteWebDriverService? {
    terminal.logLookup("- checking WebDriver endpoint: ", "WEBDRIVER_REMOTE_URL")
    guard let value = ProcessInfo.processInfo.environment["WEBDRIVER_REMOTE_URL"] else {
      return nil
    }
    guard let endporint = URL(string: value) else {
      throw WebDriverError.invalidRemoteURL(value)
    }
    return RemoteWebDriverService(endpoint: endporint)
  }

  public init(endpoint: URL) {
    self.endpoint = endpoint
  }

  public var endpoint: URL

  public func dispose() {}
}
