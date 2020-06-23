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
import Foundation
import TSCBasic

struct Install: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Install new Swift toolchain/SDK."
  )

  @Argument() var version: String?

  func run() throws {
    guard let terminal = TerminalController(stream: stdoutStream)
    else { fatalError("failed to create an instance of `TerminalController`") }

    let delegate = ResponseDelegate(expectedBytes: 891_856_371)

    let url = version.flatMap { URL(string: $0) }
    let version = try localFileSystem.inferSwiftPath(version: self.version, terminal)
    print(version)

    // let client = HTTPClient(eventLoopGroupProvider: .createNew)
    // let response: HTTPClient.Response = try await {
    //   client.get(url: archiveURL).whenComplete($0)
    // }
    // try client.syncShutdown()
  }
}
