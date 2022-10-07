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
import CartonHelpers
import SwiftToolchain
import TSCBasic

struct Local: ParsableCommand {
  static let configuration = CommandConfiguration(abstract: """
  Prints SDK version used for the current project or saves it \
  in the `.swift-version` file if a version is passed as an argument.
  """)

  @Argument() var version: String?

  func run() throws {
    let terminal = InteractiveWriter.stdout
    let toolchainSystem = ToolchainSystem(fileSystem: localFileSystem)
    
    if let version = version {
      let versions = try toolchainSystem.fetchAllSwiftVersions()
      if versions.contains(version) {
        _ = try toolchainSystem.setLocalSwiftVersion(version)
      } else {
        terminal.write("The version \(version) hasn't been installed!", inColor: .red)
      }
    } else {
      let localVersion = try toolchainSystem.fetchLocalSwiftVersion()
      if let localVersion = localVersion {
        terminal.write("\(localVersion)", inColor: .green)
      } else {
        terminal.logLookup("Version file is not present: ", toolchainSystem.swiftVersionPath)
      }
    }
  }
}
