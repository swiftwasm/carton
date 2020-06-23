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

import AsyncHTTPClient
import Foundation
import TSCBasic

func processStringOutput(_ arguments: [String]) throws -> String? {
  try ByteString(processDataOutput(arguments)).validDescription
}

extension FileSystem {
  func traverseRecursively(_ root: AbsolutePath) throws -> [AbsolutePath] {
    precondition(isDirectory(root))
    var result = [AbsolutePath]()

    var pathsToTraverse = [root]
    while let currentDirectory = pathsToTraverse.popLast() {
      let directoryContents = try getDirectoryContents(currentDirectory)
        .map(currentDirectory.appending)

      result.append(contentsOf: directoryContents)
      pathsToTraverse.append(contentsOf: directoryContents.filter(isDirectory))
    }

    return result
  }

  func inferSwiftVersion() throws -> String {
    guard let cwd = currentWorkingDirectory else { return defaultToolchainVersion }

    let versionFile = cwd.appending(component: ".swift-version")

    guard isFile(versionFile), let version = try readFileContents(versionFile)
      .validDescription?
      // get the first line of the file
      .components(separatedBy: CharacterSet.newlines).first,
      version.contains("wasm")
    else { return defaultToolchainVersion }

    return version
  }

  /** Infer `swift` binary path matching a given version if any is present, or infer the
   version from the `.swift-version` file. If neither version is installed, download it.
   */
  func inferSwiftPath(version: String? = nil, _ terminal: TerminalController) throws -> String {
    let swiftVersion = try version ?? inferSwiftVersion()

    func checkAndLog(_ prefix: AbsolutePath) -> String? {
      let swiftPath = prefix.appending(components: swiftVersion, "usr", "bin", "swift")

      guard isFile(swiftPath) else { return nil }

      terminal.write("Inferring basic settings...\n", inColor: .yellow)
      terminal.logLookup("- swift executable: ", swiftPath)

      return swiftPath.pathString
    }

    if let path = checkAndLog(homeDirectory.appending(components: ".swiftenv", "versions")) {
      return path
    }

    if let path = checkAndLog(homeDirectory.appending(components: ".carton", "sdk")) {
      return path
    }

    return swiftVersion
  }

  func inferBinPath(swiftPath: String) throws -> AbsolutePath {
    guard
      let output = try processStringOutput([
        swiftPath, "build", "--triple", "wasm32-unknown-wasi", "--show-bin-path",
      ])?.components(separatedBy: CharacterSet.newlines),
      let binPath = output.first
    else { fatalError("failed to decode UTF8 output of the `swift build` invocation") }

    return AbsolutePath(binPath)
  }
}
