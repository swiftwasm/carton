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

import OpenCombine
import TSCBasic
import Vapor

final class Server {
  // FIXME: this only handles a single connection, should maintain a collection of connections
  // and cleanup the array when one is closed
  private var wsConnection: WebSocket?
  private var subscriptions = [AnyCancellable]()
  private let watcher: Watcher
  private let app: Application

  init(pathsToWatch: [AbsolutePath], mainWasmPath: String) throws {
    watcher = try Watcher(pathsToWatch)

    var env = Environment.development
    try LoggingSystem.bootstrap(from: &env)
    app = Application(env)
    app.configure(mainWasmPath: mainWasmPath) {
      self.wsConnection = $0
    }

    watcher.publisher
      .sink { [weak self] _ in
        self?.wsConnection?.send("reload")
      }
      .store(in: &subscriptions)
  }

  /// Blocking function that starts the HTTP server
  func run() throws {
    defer { app.shutdown() }
    try app.run()
  }
}
