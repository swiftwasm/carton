import CartonHelpers
import class Foundation.Bundle
import TSCBasic
import XCTest

final class CartonTests: XCTestCase {
  /// Returns path to the built products directory.
  var productsDirectory: URL {
    #if os(macOS)
    for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
      return bundle.bundleURL.deletingLastPathComponent()
    }
    fatalError("couldn't find the products directory")
    #else
    return Bundle.main.bundleURL
    #endif
  }

  func testVersion() throws {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.

    // Some of the APIs that we use below are available in macOS 10.13 and above.
    guard #available(macOS 10.13, *) else {
      return
    }

    let fooBinary = productsDirectory.appendingPathComponent("carton")

    let process = Process()
    process.executableURL = fooBinary

    let pipe = Pipe()
    process.standardOutput = pipe

    process.arguments = ["--version"]
    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)

    XCTAssertEqual(output?.trimmingCharacters(in: .whitespacesAndNewlines), "0.8.1")
  }

  final class TestOutputStream: OutputByteStream {
    var bytes: [UInt8] = []
    var currentOutput: String {
      String(bytes: bytes, encoding: .utf8)!
    }

    var position: Int = 0

    init() {}

    func flush() {}

    func write(_ byte: UInt8) {
      bytes.append(byte)
    }

    func write<C>(_ bytes: C) where C: Collection, C.Element == UInt8 {
      self.bytes.append(contentsOf: bytes)
    }
  }

  func testDiagnosticsParser() {
    // swiftlint:disable line_length
    let testDiagnostics = """
    [1/1] Compiling TokamakCore Font.swift
    /Users/username/Project/Sources/TokamakCore/Tokens/Font.swift:58:15: error: invalid redeclaration of 'resolve(in:)'
      public func resolve(in environment: EnvironmentValues) -> _Font {
                  ^
    /Users/username/Project/Sources/TokamakCore/Tokens/Font.swift:55:15: note: 'resolve(in:)' previously declared here
      public func resolve(in environment: EnvironmentValues) -> _Font {
                  ^
    """
    let expectedOutput = """
    \u{001B}[1m\u{001B}[7m Font.swift \u{001B}[0m /Users/username/Project/Sources/TokamakCore/Tokens/Font.swift:58

      \u{001B}[41;1m\u{001B}[37;1m ERROR \u{001B}[0m  invalid redeclaration of 'resolve(in:)'
      \u{001B}[36m58 | \u{001B}[0m   \u{001B}[35;1mpublic\u{001B}[0m \u{001B}[35;1mfunc\u{001B}[0m resolve(in environment: \u{001B}[94mEnvironmentValues\u{001B}[0m) -> \u{001B}[94m_Font\u{001B}[0m {
         |                ^

      \u{001B}[7m\u{001B}[37;1m NOTE \u{001B}[0m  'resolve(in:)' previously declared here
      \u{001B}[36m55 | \u{001B}[0m   \u{001B}[35;1mpublic\u{001B}[0m \u{001B}[35;1mfunc\u{001B}[0m resolve(in environment: \u{001B}[94mEnvironmentValues\u{001B}[0m) -> \u{001B}[94m_Font\u{001B}[0m {
         |                ^



    """
    // swiftlint:enable line_length
    let stream = TestOutputStream()
    let writer = InteractiveWriter(stream: stream)
    DiagnosticsParser().parse(testDiagnostics, writer)
    XCTAssertEqual(stream.currentOutput, expectedOutput)
  }
}
