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
import Foundation
import PackageModel
import SwiftToolchain
import TSCBasic
import Vapor

extension Application {
  struct Configuration {
    let port: Int
    let host: String
    let mainWasmPath: AbsolutePath
    let customIndexPath: AbsolutePath?
    let manifest: Manifest
    let product: ProductDescription?
    let entrypoint: Entrypoint
    let onWebSocketOpen: (WebSocket, DestinationEnvironment) async -> ()
    let onWebSocketClose: (WebSocket) async -> ()
  }

  func configure(_ configuration: Configuration) throws {
    http.server.configuration.port = configuration.port
    http.server.configuration.hostname = configuration.host

    let directory = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".carton")
      .appendingPathComponent("static")
      .path
    middleware.use(FileMiddleware(publicDirectory: directory))

    // register routes
    get { (request: Request) -> EventLoopFuture<HTML> in
      let customIndexContent: EventLoopFuture<String?>
      if let path = configuration.customIndexPath?.pathString {
        customIndexContent = request.fileio.collectFile(at: path).map { String(buffer: $0) }
      } else {
        customIndexContent = request.eventLoop.makeSucceededFuture(nil)
      }

      return customIndexContent.map {
        HTML(value: HTML.indexPage(
          customContent: $0,
          entrypointName: configuration.entrypoint.fileName
        ))
      }
    }

    webSocket("watcher") { request, ws in
      let environment = request.headers["User-Agent"].compactMap(DestinationEnvironment.init).first
        ?? .other

      Task { await configuration.onWebSocketOpen(ws, environment) }
      ws.onClose.whenComplete { _ in Task { await configuration.onWebSocketClose(ws) } }
    }

    get("main.wasm") {
      // stream the file
      $0.fileio.streamFile(at: configuration.mainWasmPath.pathString)
    }

    // Serve resources for all targets at their respective paths.
    let buildDirectory = configuration.mainWasmPath.parentDirectory

    func requestHandler(_ directoryName: String) -> ((Request) -> Response) {
      { (request: Request) -> Response in
        request.fileio.streamFile(
          at: AbsolutePath(
            buildDirectory.appending(component: directoryName),
            request.parameters.getCatchall().joined(separator: "/")
          ).pathString
        )
      }
    }

    for directoryName in try localFileSystem.resourcesDirectoryNames(relativeTo: buildDirectory) {
      get(.constant(directoryName), "**", use: requestHandler(directoryName))
    }

    let inferredMainTarget = configuration.manifest.targets.first {
      configuration.product?.targets.contains($0.name) == true
    }

    // Serve resources for the main target at the root path.
    guard let mainTarget = inferredMainTarget else { return }

    let resourcesPath = configuration.manifest.resourcesPath(for: mainTarget)
    get("**", use: requestHandler(resourcesPath))
  }
}
