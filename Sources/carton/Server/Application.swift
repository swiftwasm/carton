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
import Vapor

extension Application {
  func configure(mainWasmPath: String, onWSConnection: @escaping (WebSocket) -> ()) {
    let directory = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".carton")
      .appendingPathComponent("static")
      .path
    middleware.use(FileMiddleware(publicDirectory: directory))

    // register routes
    routes(mainWasmPath: mainWasmPath, onWSConnection: onWSConnection)
  }

  private func routes(mainWasmPath: String, onWSConnection: @escaping (WebSocket) -> ()) {
    get { _ in
      HTML(value: #"""
      <html>
        <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <script type="text/javascript" src="dev.js"></script>
        </head>
        <body>
            <h1>Hello!</h1>
        </body>
      </html>
      """#)
    }

    webSocket("watcher") { _, ws in
      onWSConnection(ws)
    }

    get("main.wasm") { (request: Request) in
      // stream the file
      request.eventLoop.makeSucceededFuture(request.fileio.streamFile(at: mainWasmPath))
    }
  }
}
