import JavaScriptKit
import XCTest

final class NodeJSKitTestTests: XCTestCase {
  func testExample() throws {
    let require = JSObject.global.require.function!
    let Buffer = require("buffer").object!.Buffer.function!

    let testString = "Hello"
    let base64String = Buffer.from!(testString).toString("base64")
    let decodedString = Buffer.from!(base64String, "base64").toString("ascii").string!

    XCTAssertEqual(decodedString, testString)
  }
}
