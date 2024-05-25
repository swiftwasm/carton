import XCTest
import CartonCore
import CartonHelpers
import CartonKit
import SwiftToolchain

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
      let tools = try ToolchainSystem(fileSystem: fs)
      let (builderSwift, _) = try await tools.inferSwiftPath(terminal)

      var args: [String] = [
        builderSwift.pathString, "build", "--triple", "wasm32-unknown-wasi"
      ]
      args += Environment.browser.buildParameters().asBuildArguments()

      try await Process.run(args, terminal)
    }

    try await Process.run(["swift", "build", "--target", "carton-frontend"], terminal)

    var gotHelloStdout = false
    var gotHelloStderr = false

    let devServer = Process(
      arguments: [
        "swift", "run", "carton-frontend", "dev",
        "--skip-auto-open", "--verbose",
        "--main-wasm-path", wasmFile.pathString,
        "--resources", resourcesDir.pathString
      ],
      outputRedirection: .stream(
        stdout: { (chunk) in
          let string = String(decoding: chunk, as: UTF8.self)

          if string.contains("stdout: hello stdout") {
            gotHelloStdout = true
          }
          if string.contains("stderr: hello stderr") {
            gotHelloStderr = true
          }

          terminal.write(string)
        }, stderr: { (_) in },
        redirectStderr: true
      )
    )
    try devServer.launch()
    defer {
      devServer.signal(SIGINT)
    }

    let host = try URL(string: "http://127.0.0.1:8080").unwrap("url")

    do {
      let indexHtml = try await withRetry(
        maxAttempts: 5, initialDelay: .seconds(3), retryInterval: .seconds(10)
      ) {
        try await fetchString(at: host)
      }

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
    }

    do {
      let devJs = try await fetchString(at: host.appendingPathComponent("dev.js"))
      let expected = try XCTUnwrap(String(data: StaticResource.dev, encoding: .utf8))
      XCTAssertEqual(devJs, expected)
    }

    do {
      let mainWasm = try await fetchBinary(at: host.appendingPathComponent("main.wasm"))
      let expected = try Data(contentsOf: wasmFile.asURL)
      XCTAssertEqual(mainWasm, expected)
    }

    do {
      let name = "style.css"
      let styleCss = try await fetchString(at: host.appendingPathComponent(name))
      let expected = try String(contentsOf: resourcesDir.appending(component: name).asURL)
      XCTAssertEqual(styleCss, expected)
    }

    try openInSystemBrowser(url: host)

    for _ in 0..<30 {
      try await Task.sleep(for: .seconds(1))
      if gotHelloStdout, gotHelloStderr { break }
    }

    XCTAssertTrue(gotHelloStdout)
    XCTAssertTrue(gotHelloStderr)
  }

  private func fetchBinary(
    at url: URL,
    file: StaticString = #file, line: UInt = #line
  ) async throws -> Data {
    let (response, body) = try await fetchWebContent(at: url, timeout: .seconds(10))
    XCTAssertEqual(response.statusCode, 200, file: file, line: line)
    return body
  }

  private func fetchString(
    at url: URL,
    file: StaticString = #file, line: UInt = #line
  ) async throws -> String? {
    let data = try await fetchBinary(at: url)

    guard let string = String(data: data, encoding: .utf8) else {
      XCTFail("not UTF-8 string content", file: file, line: line)
      return nil
    }

    return string
  }
}
