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

import CartonHelpers
import CartonKit
import Foundation
import PackageModel
import TSCBasic

private enum Constants {
  static let entrypoint = Entrypoint(fileName: "test.js", sha256: testEntrypointSHA256)
}

struct BrowserTestRunner: TestRunner {
  let testFilePath: AbsolutePath
  let host: String
  let port: Int
  let manifest: Manifest
  let terminal: InteractiveWriter

  func run() async throws {
    try Constants.entrypoint.check(on: localFileSystem, terminal)
    try await Server(
      .init(
        builder: nil,
        mainWasmPath: testFilePath,
        verbose: true,
        shouldSkipAutoOpen: false,
        port: port,
        host: host,
        customIndexContent: nil,
        manifest: manifest,
        product: nil,
        entrypoint: Constants.entrypoint,
        terminal: terminal
      )
    ).run()
  }
}
