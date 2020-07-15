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
import SwiftToolchain
import TSCBasic

struct Versions: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Lists all installed toolchains/SDKs"
  )

  func run() throws {
    guard let terminal = TerminalController(stream: stdoutStream)
    else { fatalError("failed to create an instance of `TerminalController`") }

    let versions = try localFileSystem.fetchAllSwiftVersions()
    let localVersion = try localFileSystem.fetchLocalSwiftVersion()
    if versions.count > 0 {
      versions.forEach { version in
        if version == (localVersion ?? "") {
          terminal.write("* \(version) (local)\n", inColor: .green)
        } else {
          terminal.write("  \(version)\n", inColor: .white)
        }
      }
    } else {
      terminal.write("No sdks installed\n")
    }
  }
}
