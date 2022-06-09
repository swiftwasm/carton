import AsyncHTTPClient
import WebDriverClient
import XCTest

final class WebDriverClientTests: XCTestCase {
  let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)

  override func tearDown() async throws {
    try httpClient.syncShutdown()
  }

  func checkRemoteURL() throws -> URL {
    guard let value = ProcessInfo.processInfo.environment["WEBDRIVER_REMOTE_URL"] else {
      throw XCTSkip("Skip WebDriver tests due to no WEBDRIVER_REMOTE_URL env var")
    }
    return try XCTUnwrap(URL(string: value), "Invalid URL string: \(value)")
  }

  func testGoto() async throws {
    let client = try await WebDriverClient.newSession(
      endpoint: checkRemoteURL(), httpClient: httpClient
    )
    try await client.goto(url: "https://example.com")
    try await client.closeSession()
  }
}
