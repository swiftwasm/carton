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

import Foundation
import TSCBasic

extension FileSystem {
  func traverseRecursively(_ root: AbsolutePath) throws -> [AbsolutePath] {
    precondition(isDirectory(root))
    var result = [AbsolutePath]()

    var pathsToTraverse = [root]
    while let currentDirectory = pathsToTraverse.popLast() {
      let directoryContents = try localFileSystem.getDirectoryContents(currentDirectory)
        .map(currentDirectory.appending)

      result.append(contentsOf: directoryContents)
      pathsToTraverse.append(contentsOf: directoryContents.filter(isDirectory))
    }

    return result
  }

  func inferSwiftPath(_ terminal: TerminalController) throws -> String {
    guard let cwd = localFileSystem.currentWorkingDirectory
    else { fatalError("failed to infer the current working directory") }

    terminal.write("Inferring basic settings...\n", inColor: .yellow)

    let swiftPath: String
    if
      let versionString = try readFileContents(cwd.appending(component: ".swift-version"))
      .validDescription,
      // get the first line of the file
      let swiftVersion = versionString.components(separatedBy: CharacterSet.newlines).first {
      swiftPath = localFileSystem.homeDirectory
        .appending(components: ".swiftenv", "versions", swiftVersion, "usr", "bin", "swift")
        .pathString
    } else {
      swiftPath = "swift"
    }
    terminal.logLookup("- swift executable: ", swiftPath)

    return swiftPath
  }
}
