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
import SwiftToolchain
import TSCBasic
import Vapor

extension Application {
  struct Configuration {
    let port: Int
    let host: String
    let mainWasmPath: AbsolutePath
    let customIndexContent: String?
    let package: SwiftToolchain.Package
    let product: Product?
    let entrypoint: Entrypoint
    let onWebSocketOpen: (WebSocket, DestinationEnvironment) -> ()
    let onWebSocketClose: (WebSocket) -> ()
  }

  func configure(with configuration: Configuration) {
    http.server.configuration.port = configuration.port
    http.server.configuration.hostname = configuration.host

    let directory = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".carton")
      .appendingPathComponent("static")
      .path
    middleware.use(FileMiddleware(publicDirectory: directory))

    // register routes
    get { _ in
      HTML(value: HTML.indexPage(
        customContent: configuration.customIndexContent,
        entrypointName: configuration.entrypoint.fileName
      ))
    }

    webSocket("watcher") { request, ws in
      let environment = request.headers["User-Agent"].compactMap(DestinationEnvironment.init).first
        ?? .other

      configuration.onWebSocketOpen(ws, environment)
      ws.onClose.whenComplete { _ in configuration.onWebSocketClose(ws) }
    }

    get("main.wasm") {
      // stream the file
      $0.eventLoop
        .makeSucceededFuture($0.fileio.streamFile(at: configuration.mainWasmPath.pathString))
    }

    let buildDirectory = configuration.mainWasmPath.parentDirectory
    for target in configuration.package.targets
      where target.type == .regular && !target.resources.isEmpty
    {
      let resourcesPath = configuration.package.resourcesPath(for: target)
      get(.constant(resourcesPath), "**") {
        $0.eventLoop.makeSucceededFuture($0.fileio.streamFile(at: AbsolutePath(
          buildDirectory.appending(component: resourcesPath),
          $0.parameters.getCatchall().joined(separator: "/")
        ).pathString))
      }
    }

    let inferredMainTarget = configuration.package.targets.first {
      configuration.product?.targets.contains($0.name) == true
    }

    guard let mainTarget = inferredMainTarget else { return }

    let resourcesPath = configuration.package.resourcesPath(for: mainTarget)
    get("**") {
      $0.eventLoop.makeSucceededFuture($0.fileio.streamFile(at: AbsolutePath(
        buildDirectory.appending(component: resourcesPath),
        $0.parameters.getCatchall().joined(separator: "/")
      ).pathString))
    }
  }
}
