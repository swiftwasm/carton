// Copyright 2020 Carton contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArgumentParser
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif
import TSCBasic

private let dependency = Dependency(
  fileName: "test.js",
  sha256: ByteString([])
)

struct Test: ParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Run the tests in a WASI environment.")

  func run() throws {
    guard let terminal = TerminalController(stream: stdoutStream)
    else { fatalError("failed to create an instance of `TerminalController`") }

    // try dependency.check(on: localFileSystem, terminal)
    // let swiftPath = try localFileSystem.inferSwiftPath(terminal)

    // let package = try Package(with: swiftPath, terminal)
    // let binPath = try localFileSystem.inferBinPath(swiftPath: swiftPath)
    // let testBundlePath = binPath.appending(component: "\(package.name)PackageTests.xctest")
    // terminal.logLookup("- test bundle: ", testBundlePath)

    // let output = try processStringOutput(["wasmer", testBundlePath.pathString])!
    // print("output is: \n\(output)")
  }
}
