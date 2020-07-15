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
import CartonHelpers
import SwiftToolchain
import TSCBasic

struct Test: ParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Run the tests in a WASI environment.")

  @Flag(help: "When specified, build in the release mode.")
  var release = false

  @Flag(name: .shortAndLong, help: "When specified, list all available test cases.")
  var list = false

  @Argument
  var testCases = [String]()

  func run() throws {
    guard let terminal = TerminalController(stream: stdoutStream)
    else { fatalError("failed to create an instance of `TerminalController`") }

    let toolchain = try Toolchain(localFileSystem, terminal)
    let testBundlePath = try toolchain.buildTestBundle(isRelease: release)

    terminal.write("\nRunning the test bundle with wasmer:\n", inColor: .yellow)
    var wasmerArguments = ["wasmer", testBundlePath.pathString]
    if list {
      wasmerArguments.append(contentsOf: ["--", "-l"])
    } else if !testCases.isEmpty {
      wasmerArguments.append("--")
      wasmerArguments.append(contentsOf: testCases)
    }
    let runner = ProcessRunner(wasmerArguments, terminal)

    try runner.waitUntilFinished()
  }
}
