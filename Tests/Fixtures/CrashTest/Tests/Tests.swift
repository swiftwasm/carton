import XCTest

class Tests: XCTestCase {
  func testCrash() {
    // recursive call would cause stack overflow
    testCrash()
  }
}
