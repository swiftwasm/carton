import CartonHelpers
import Foundation

public protocol WebDriverService {
  static func find(
    terminal: InteractiveWriter
  ) async throws -> Self?

  func dispose()

  var endpoint: URL { get }
}

extension WebDriverService {
  public func client(
    httpClient: (any WebDriverHTTPClient)? = nil
  ) async throws -> WebDriverClient {
    let httpClient = httpClient ?? WebDriverHTTPClients.find()

    return try await withRetry(maxAttempts: 3, initialDelay: .zero, retryInterval: .seconds(1)) {
      try await WebDriverClient.newSession(
        endpoint: endpoint,
        httpClient: httpClient
      )
    }
  }
}

public enum WebDriverServices {
  public static func find(
    terminal: InteractiveWriter
  ) async throws -> any WebDriverService {
    if let service = try await RemoteWebDriverService.find(terminal: terminal) {
      return service
    }

    if let service = try await CommandWebDriverService.find(terminal: terminal) {
      return service
    }

    throw WebDriverError.failedToFindWebDriver
  }
}
