import XCTest
import CartonCore
import CartonHelpers
import CartonKit
import SwiftToolchain
import WebDriver

struct DevServerClient {
  var process: CartonHelpers.Process

  init(
    wasmFile: AbsolutePath,
    resourcesDir: AbsolutePath,
    terminal: InteractiveWriter,
    onStdout: ((String) -> Void)?
  ) throws {
    process = Process(
      arguments: [
        "swift", "run", "carton-frontend", "dev",
        "--skip-auto-open", "--verbose",
        "--main-wasm-path", wasmFile.pathString,
        "--resources", resourcesDir.pathString
      ],
      outputRedirection: .stream(
        stdout: { (chunk) in
          let string = String(decoding: chunk, as: UTF8.self)

          onStdout?(string)

          terminal.write(string)
        }, stderr: { (_) in },
        redirectStderr: true
      )
    )
    try process.launch()
  }

  func dispose() {
    process.signal(SIGINT)
  }

  func fetchBinary(
    at url: URL,
    file: StaticString = #file, line: UInt = #line
  ) async throws -> Data {
    let (response, body) = try await withRetry(
      maxAttempts: 5, initialDelay: .seconds(3), retryInterval: .seconds(10)
    ) {
      try await fetchWebContent(at: url, timeout: .seconds(10))
    }
    XCTAssertEqual(response.statusCode, 200, file: file, line: line)

    try checkServerNameField(response: response, expectedPID: process.processID)

    return body
  }

  func fetchString(
    at url: URL,
    file: StaticString = #file, line: UInt = #line
  ) async throws -> String {
    let data = try await fetchBinary(at: url, file: file, line: line)

    guard let string = String(data: data, encoding: .utf8) else {
      throw CommandTestError("not UTF-8 string content")
    }

    return string
  }

  func fetchContentSize(
    at url: URL, file: StaticString = #file, line: UInt = #line
  ) async throws -> Int {
    let httpResponse = try await fetchHead(at: url, timeout: .seconds(10))
    let contentLength = try XCTUnwrap(httpResponse.allHeaderFields["Content-Length"] as? String)
    return Int(contentLength)!
  }
}

final class FrontendDevServerTests: XCTestCase {
  func testDevServerPublish() async throws {
    let fs = localFileSystem
    let terminal = InteractiveWriter.stdout
    let projectDir = try testFixturesDirectory.appending(component: "DevServerTestApp")
    let buildDir = projectDir.appending(components: [".build", "wasm32-unknown-wasi", "debug"])
    let wasmFile = buildDir.appending(component: "app.wasm")
    let resourcesDir = buildDir.appending(component: "DevServerTestApp_app.resources")

    try fs.changeCurrentWorkingDirectory(to: projectDir)

    if !fs.exists(wasmFile) {
      let tools = try ToolchainSystem(fileSystem: .default)
      let builderSwift = try await tools.inferSwiftPath(terminal)

      var args: [String] = [
        builderSwift.swift.path, "build", "--triple", "wasm32-unknown-wasi"
      ]
      args += Environment.browser.buildParameters().asBuildArguments()

      try await Process.run(args, terminal)
    }

    try await Process.run(["swift", "build", "--target", "carton-frontend"], terminal)

    var gotHelloStdout = false
    var gotHelloStderr = false

    let cl = try DevServerClient(
      wasmFile: wasmFile,
      resourcesDir: resourcesDir,
      terminal: terminal,
      onStdout: { (string) in
        if string.contains("stdout: hello stdout") {
          gotHelloStdout = true
        }
        if string.contains("stderr: hello stderr") {
          gotHelloStderr = true
        }
      }
    )
    defer {
      cl.dispose()
    }

    let host = try URL(string: "http://127.0.0.1:8080").unwrap("url")

    do {
      let indexHtml = try await cl.fetchString(at: host)

      XCTAssertEqual(indexHtml, """
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <script type="module" src="dev.js"></script>
          </head>
          <body>
          </body>
        </html>
        """
      )
      let contentSize = try await cl.fetchContentSize(at: host)
      XCTAssertEqual(contentSize, indexHtml.utf8.count)
    }

    do {
      let url = host.appendingPathComponent("dev.js")
      let devJs = try await cl.fetchString(at: url)
      let expected = try XCTUnwrap(String(data: StaticResource.dev, encoding: .utf8))
      XCTAssertEqual(devJs, expected)
      let contentSize = try await cl.fetchContentSize(at: url)
      XCTAssertEqual(contentSize, expected.utf8.count)
    }

    do {
      let url = host.appendingPathComponent("main.wasm")
      let mainWasm = try await cl.fetchBinary(at: url)
      let expected = try Data(contentsOf: wasmFile.asURL)
      XCTAssertEqual(mainWasm, expected)
      let contentSize = try await cl.fetchContentSize(at: url)
      XCTAssertEqual(contentSize, expected.count)
    }

    for name in ["style.css", "space separated.txt"] {
      let styleCss = try await cl.fetchString(at: host.appendingPathComponent(name))
      let expected = try String(contentsOf: resourcesDir.appending(component: name).asURL)
      XCTAssertEqual(styleCss, expected)
      let contentSize = try await cl.fetchContentSize(at: host.appendingPathComponent(name))
      XCTAssertEqual(contentSize, expected.utf8.count)
    }

    let webDriver = try await WebDriverServices.find(terminal: terminal)
    defer {
      webDriver.dispose()
    }

    let webDriverClient = try await webDriver.client()

    try await webDriverClient.goto(url: host)

    try await withRetry(maxAttempts: 10, initialDelay: .seconds(3), retryInterval: .seconds(3)) {
      if gotHelloStdout, gotHelloStderr {
        return
      }
      throw CommandTestError("no output")
    }

    try await webDriverClient.closeSession()
  }
}
