// Copyright 2022 Carton contributors
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

import CartonHelpers
import CartonKit
import Foundation

private enum Constants {
  static let entrypoint = Entrypoint(fileName: "testNode.js", content: StaticResource.testNode)
}

/// Test runner for Node.js.
struct NodeTestRunner: TestRunner {
  let pluginWorkDirectory: AbsolutePath
  let testFilePath: AbsolutePath
  let listTestCases: Bool
  let testCases: [String]
  let nodeArguments: [String]
  let terminal: InteractiveWriter

  func run(options: TestRunnerOptions) async throws {
    terminal.write("\nRunning the test bundle with Node.js:\n", inColor: .yellow)

    let entrypointPath = try Constants.entrypoint.write(
      at: pluginWorkDirectory, fileSystem: localFileSystem
    )

    // Allow Node.js to resolve modules from resource directories by making them relative to the entrypoint path.
    let buildDirectory = testFilePath.parentDirectory
    let staticDirectory = pluginWorkDirectory

    // Clean up existing symlinks before creating new ones.
    for existingSymlink in try localFileSystem.resourcesDirectoryNames(relativeTo: staticDirectory)
    {
      try localFileSystem.removeFileTree(staticDirectory.appending(component: existingSymlink))
    }

    let resourceDirectories = try localFileSystem.resourcesDirectoryNames(
      relativeTo: buildDirectory)

    // Create new symlink for each resource directory.
    for resourcesDirectoryName in resourceDirectories {
      try localFileSystem.createSymbolicLink(
        staticDirectory.appending(component: resourcesDirectoryName),
        pointingAt: buildDirectory.appending(component: resourcesDirectoryName),
        relative: false
      )
    }

    var nodeArguments =
      ["node"] + nodeArguments + [entrypointPath.pathString, testFilePath.pathString]
    if listTestCases {
      nodeArguments.append(contentsOf: ["--", "-l"])
    } else if !testCases.isEmpty {
      nodeArguments.append(contentsOf: testCases)
    }
    try await Process.run(nodeArguments, environment: options.env, terminal)
  }
}
