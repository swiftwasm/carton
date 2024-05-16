import XCTest
import NIOConcurrencyHelpers
import SwiftToolchain
import CartonHelpers

final class FrontendDevServerTests: XCTestCase {
  func testDevServerPublish() async throws {
    let fs = localFileSystem
    let terminal = InteractiveWriter.stdout
    let dir = try testFixturesDirectory.appending(component: "DevServerTestApp")
    let productDir = dir.appending(components: [".build", "wasm32-unknown-wasi", "debug"])
    let appWasmFile = productDir.appending(component: "app.wasm")
    let targetResourceDir = productDir.appending(component: "DevServerTestApp_app.resources")

    let tools = try ToolchainSystem(fileSystem: fs)
    let (wasmSwift, _) = try await tools.inferSwiftPath(terminal)

    let swift = try findSwiftExecutable()

    try fs.changeCurrentWorkingDirectory(to: dir)

    if !fs.exists(appWasmFile) {
      try await Process.run(
        [
          wasmSwift.pathString, "build",
          "--triple", "wasm32-unknown-wasi",
          "--disable-build-manifest-caching",
          "--static-swift-stdlib",
          "-Xswiftc", "-Xclang-linker", "-Xswiftc", "-mexec-model=reactor",
          "-Xlinker", "--export-if-defined=main"
        ],
        terminal
      )
    }

    try await Process.run(
      [
        swift.pathString, "build", "--target", "CartonFrontend"
      ],
      terminal
    )

    let process = Process(
      arguments: [
        swift.pathString, "run", "CartonFrontend", "dev",
        "--skip-auto-open", "--verbose",
        "--main-wasm-path", appWasmFile.pathString,
        "--resources", targetResourceDir.pathString
      ],
      outputRedirection: .stream(
        stdout: { (bytes) in
          guard let string = String(data: Data(bytes), encoding: .utf8) else { return }
          terminal.write(string)
        }, stderr: { _ in }, redirectStderr: true
      )
    )
    try process.launch()

    defer {
      process.signal(SIGINT)
    }

    try await Task.sleep(for: .seconds(3))

    let url = "http://localhost:8080"

    let index = try await curl(url: url)
    XCTAssertEqual(index, """
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

    do {
      let devJs = try await curl(url: url + "/dev.js")
      _ = devJs
    } catch {
      XCTExpectFailure {
        XCTFail("\(error)")
      }
    }

    let serverMainWasm = try await curlBinary(url: url + "/main.wasm")
    let localAppWasm = try Data(contentsOf: appWasmFile.asURL)
    XCTAssertTrue(serverMainWasm == localAppWasm)

    let css = try await curl(url: url + "/style.css")
    XCTAssertEqual(css, """
      * {
        margin: 0;
        padding: 0;
      }
      """
    )

    process.signal(SIGINT)
    _ = try await process.waitUntilExit()
  }

  private func curl(url: String) async throws -> String {
    let data = try await curlBinary(url: url)
    return String(decoding: data, as: UTF8.self)
  }

  private func curlBinary(url: String) async throws -> Data {
    let bin = try findExecutable(name: "curl").pathString
    let proc = Process(arguments: [bin, "-LfSs", "--output", "-", url])
    try proc.launch()
    let result = try await proc.waitUntilExit()
    guard result.exitStatus == .terminated(code: EXIT_SUCCESS) else {
      throw ProcessResult.Error.nonZeroExit(result)
    }
    return Data(try result.output.get())
  }

}
