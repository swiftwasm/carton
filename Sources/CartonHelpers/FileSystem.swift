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

public extension String {
  var isAbsolutePath: Bool { first == "/" }
}

public extension FileSystem {
  func traverseRecursively(_ traversalRoot: AbsolutePath) throws -> [AbsolutePath] {
    guard exists(traversalRoot, followSymlink: true) else {
      return []
    }

    var result = [traversalRoot]

    guard isDirectory(traversalRoot) else {
      return result
    }

    var pathsToTraverse = result
    while let currentDirectory = pathsToTraverse.popLast() {
      let directoryContents = try getDirectoryContents(currentDirectory)
        .map(currentDirectory.appending)

      result.append(contentsOf: directoryContents)
      pathsToTraverse.append(contentsOf: directoryContents.filter(isDirectory))
    }

    return result
  }

  func humanReadableFileSize(_ path: AbsolutePath) throws -> String {
    precondition(isFile(path))

    // FIXME: should use `UnitInformationStorage`, but it's unavailable in open-source Foundation
    return try String(format: "%.2f MB", Double(getFileInfo(path).size) / 1024 / 1024)
  }
}
