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

import CartonCore
import CartonHelpers
import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

struct JavaScriptTestRunner: TestRunner {
  let testHarness: String
  let pluginWorkDirectory: AbsolutePath
  let testFilePath: AbsolutePath
  let resourcesPaths: [String]
  let nodeArguments: [String]
  let terminal: InteractiveWriter

  init(
    testHarness: String,
    pluginWorkDirectory: AbsolutePath,
    testFilePath: AbsolutePath,
    resourcesPaths: [String],
    nodeArguments: [String],
    terminal: InteractiveWriter
  ) {
    self.testHarness = testHarness
    self.pluginWorkDirectory = pluginWorkDirectory
    self.testFilePath = testFilePath
    self.resourcesPaths = resourcesPaths
    self.nodeArguments = nodeArguments
    self.terminal = terminal
  }

  func run(options: TestRunnerOptions) async throws {
    try localFileSystem.removeFileTree(pluginWorkDirectory)
    try localFileSystem.createDirectory(pluginWorkDirectory, recursive: false)
    let buildDirectory = testFilePath.parentDirectory
    try BundleLayout(
      mainModuleBaseName: "test", wasmSourcePath: testFilePath,
      buildDirectory: buildDirectory,
      bundleDirectory: pluginWorkDirectory,
      topLevelResourcePaths: resourcesPaths
    ).copyTestEntrypoint(contentHash: false, terminal: terminal)

    var arguments =
      ["node"] + nodeArguments + [pluginWorkDirectory.appending(component: testHarness).pathString]
    options.applyXCTestArguments(to: &arguments)
    try await runTestProcess(
      arguments, environment: options.env, parser: options.testsParser, terminal)
  }
}
