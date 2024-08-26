import XCTest

class Tests: XCTestCase {
  func testEnvVar() {
    XCTAssertEqual(ProcessInfo.processInfo.environment["FOO"], "BAR")
    XCTAssertEqual(ProcessInfo.processInfo.environment["BAZ"], "QUX")
  }
}
