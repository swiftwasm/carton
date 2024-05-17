import XCTest
import CartonHelpers

final class ProcessTests: XCTestCase {
  func testProcessEnv() async throws {
    let proc = Process(
      arguments: ["/usr/bin/env"],
      environmentBlock: ["PATH": "/usr/local/bin:/usr/bin"]
    )
    try proc.launch()
    let result = try await proc.waitUntilExit()
    let out = try result.utf8Output()
      .trimmingCharacters(in: .whitespacesAndNewlines)
    XCTAssertEqual(out, "PATH=/usr/local/bin:/usr/bin")
  }
}
