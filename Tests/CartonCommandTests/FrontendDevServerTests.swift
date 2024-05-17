import XCTest
import NIOConcurrencyHelpers
import SwiftToolchain
import CartonHelpers

final class FrontendDevServerTests: XCTestCase {
  func testDevServerPublish() async throws {
    let fs = localFileSystem
    
    // CI-DEBUG

    print("TRACE env begin --------")
    print(try await Process.checkNonZeroExit(arguments: ["/usr/bin/env"]))
    print("TRACE env end --------")

    let homeDir = ProcessInfo.processInfo.environment["HOME"]!

    print("TRACE fs home=\(homeDir)")

    let homeItems = try fs.getDirectoryContents(AbsolutePath(validating: homeDir))
    print(homeItems)

    if homeItems.contains(".carton") {
      print("TRACE dot carton")
      let dotCartonItems = try fs.getDirectoryContents(AbsolutePath(validating: homeDir + "/.carton"))
      print(dotCartonItems)
    }



    let terminal = InteractiveWriter.stdout
    let dir = try testFixturesDirectory.appending(component: "DevServerTestApp")
    let productDir = dir.appending(components: [".build", "wasm32-unknown-wasi", "debug"])
    let appWasmFile = productDir.appending(component: "app.wasm")
    let targetResourceDir = productDir.appending(component: "DevServerTestApp_app.resources")

    let tools = try ToolchainSystem(fileSystem: fs)
    let (wasmSwift, _) = try await tools.inferSwiftPath(terminal)

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
        wasmSwift.pathString, "build", "--target", "CartonFrontend"
      ],
      terminal
    )

    print("TRACE \(#line)")

    let process = Process(
      arguments: [
        wasmSwift.pathString, "run", "CartonFrontend", "dev",
        "--skip-auto-open", "--verbose",
        "--main-wasm-path", appWasmFile.pathString,
        "--resources", targetResourceDir.pathString
      ],
      outputRedirection: .stream(
        stdout: { (bytes) in
          let string = String(decoding: bytes, as: UTF8.self)
          terminal.write(string)
        }, stderr: { _ in }, redirectStderr: true
      )
    )
    print("TRACE \(#line)")
    try process.launch()

    defer {
      print("TRACE \(#line)")
      process.signal(SIGINT)
    }

    print("TRACE \(#line)")
    try await Task.sleep(for: .seconds(3))

    let url = "http://localhost:8080"

    print("TRACE \(#line)")
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

    print("TRACE \(#line)")

    do {
      let devJs = try await curl(url: url + "/dev.js")
      _ = devJs
      XCTFail("Currently, due to a bug, `dev.js` is not being delivered")
    } catch {
    }
    print("TRACE \(#line)")

    let serverMainWasm = try await curlBinary(url: url + "/main.wasm")
    print("TRACE \(#line)")
    let localAppWasm = try Data(contentsOf: appWasmFile.asURL)
    print("TRACE \(#line)")
    XCTAssertTrue(serverMainWasm == localAppWasm)

    print("TRACE \(#line)")
    let css = try await curl(url: url + "/style.css")
    XCTAssertEqual(css, """
      * {
        margin: 0;
        padding: 0;
      }
      """
    )

    process.signal(SIGINT)
    print("TRACE \(#line)")
    _ = try await process.waitUntilExit()
    print("TRACE \(#line)")
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
