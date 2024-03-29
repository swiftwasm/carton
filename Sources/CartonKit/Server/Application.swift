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
import Logging
import NIO
import NIOHTTP1
import NIOWebSocket

extension Server {
  final class HTTPHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    struct Configuration {
      let logger: Logger
      let mainWasmPath: AbsolutePath
      let customIndexPath: AbsolutePath?
      let resourcesPaths: [String]
      let entrypoint: Entrypoint
    }

    let configuration: Configuration
    private var responseBody: ByteBuffer!

    init(configuration: Configuration) {
      self.configuration = configuration
    }

    func handlerAdded(context: ChannelHandlerContext) {
    }

    func handlerRemoved(context: ChannelHandlerContext) {
      self.responseBody = nil
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      let reqPart = self.unwrapInboundIn(data)

      // We're not interested in request bodies here
      guard case .head(let head) = reqPart else {
        return
      }

      // GETs only.
      guard case .GET = head.method else {
        self.respond405(context: context)
        return
      }
      configuration.logger.info("\(head.method) \(head.uri)")

      let response: StaticResponse
      do {
        switch head.uri {
        case "/":
          response = try respondIndexPage(context: context)
        case "/main.wasm":
          response = StaticResponse(
            contentType: "application/wasm",
            body: try context.channel.allocator.buffer(
              bytes: localFileSystem.readFileContents(configuration.mainWasmPath).contents
            )
          )
        default:
          guard let staticResponse = try self.respond(context: context, head: head) else {
            self.respond404(context: context)
            return
          }
          response = staticResponse
        }
      } catch {
        configuration.logger.error("Failed to respond to \(head.uri): \(error)")
        response = StaticResponse(
          contentType: "text/plain",
          body: context.channel.allocator.buffer(string: "Internal server error")
        )
      }
      self.responseBody = response.body

      var headers = HTTPHeaders()
      headers.add(name: "Content-Type", value: response.contentType)
      headers.add(name: "Content-Length", value: String(response.body.readableBytes))
      headers.add(name: "Connection", value: "close")
      let responseHead = HTTPResponseHead(
        version: .init(major: 1, minor: 1),
        status: .ok,
        headers: headers)
      context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
      context.write(self.wrapOutboundOut(.body(.byteBuffer(response.body))), promise: nil)
      context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
        context.close(promise: nil)
      }
      context.flush()
    }

    struct StaticResponse {
      let contentType: String
      let body: ByteBuffer
    }

    private func respond(context: ChannelHandlerContext, head: HTTPRequestHead) throws
      -> StaticResponse?
    {
      var responders = [
        self.makeStaticResourcesResponder(
          baseDirectory: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".carton")
            .appendingPathComponent("static")
        )
      ]

      let buildDirectory = configuration.mainWasmPath.parentDirectory
      for directoryName in try localFileSystem.resourcesDirectoryNames(relativeTo: buildDirectory) {
        responders.append { context, uri in
          let parts = uri.split(separator: "/")
          guard let firstPart = parts.first,
            firstPart == directoryName
          else { return nil }
          let baseDir = URL(fileURLWithPath: buildDirectory.pathString).appendingPathComponent(
            directoryName
          )
          let inner = self.makeStaticResourcesResponder(baseDirectory: baseDir)
          return try inner(context, "/" + parts.dropFirst().joined(separator: "/"))
        }
      }

      // Serve resources for the main target at the root path.
      for mainResourcesPath in configuration.resourcesPaths {
        responders.append(
          self.makeStaticResourcesResponder(baseDirectory: URL(fileURLWithPath: mainResourcesPath)))
      }

      for responder in responders {
        if let response = try responder(context, head.uri) {
          return response
        }
      }
      return nil
    }

    private func makeStaticResourcesResponder(
      baseDirectory: URL
    ) -> (_ context: ChannelHandlerContext, _ uri: String) throws -> StaticResponse? {
      return { context, uri in
        assert(uri.first == "/")
        let fileURL = baseDirectory.appendingPathComponent(String(uri.dropFirst()))
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
          !isDir.boolValue
        else {
          return nil
        }
        let contentType = self.contentType(of: fileURL) ?? "application/octet-stream"

        return StaticResponse(
          contentType: contentType,
          body: try context.channel.allocator.buffer(bytes: Data(contentsOf: fileURL))
        )
      }
    }

    private func contentType(of filePath: URL) -> String? {
      let typeByExtension = [
        "js": "application/javascript",
        "mjs": "application/javascript",
        "wasm": "application/wasm",
      ]
      return typeByExtension[filePath.pathExtension]
    }

    private func respondIndexPage(context: ChannelHandlerContext) throws -> StaticResponse {
      var customIndexContent: String?
      if let path = configuration.customIndexPath?.pathString {
        customIndexContent = try String(contentsOfFile: path)
      }
      let htmlContent = HTML.indexPage(
        customContent: customIndexContent,
        entrypointName: configuration.entrypoint.fileName
      )
      return StaticResponse(
        contentType: "text/html",
        body: context.channel.allocator.buffer(string: htmlContent)
      )
    }

    private func respond405(context: ChannelHandlerContext) {
      var headers = HTTPHeaders()
      headers.add(name: "Connection", value: "close")
      headers.add(name: "Content-Length", value: "0")
      let head = HTTPResponseHead(
        version: .http1_1,
        status: .methodNotAllowed,
        headers: headers)
      context.write(self.wrapOutboundOut(.head(head)), promise: nil)
      context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
        context.close(promise: nil)
      }
      context.flush()
    }

    private func respond404(context: ChannelHandlerContext) {
      var headers = HTTPHeaders()
      headers.add(name: "Connection", value: "close")
      headers.add(name: "Content-Length", value: "0")
      let head = HTTPResponseHead(
        version: .http1_1,
        status: .notFound,
        headers: headers)
      context.write(self.wrapOutboundOut(.head(head)), promise: nil)
      context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
        context.close(promise: nil)
      }
      context.flush()
    }
  }

  final class WebSocketHandler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame

    struct Configuration {
      let onText: @Sendable (String) -> Void
    }

    private var awaitingClose: Bool = false
    let configuration: Configuration

    init(configuration: Configuration) {
      self.configuration = configuration
    }

    public func handlerAdded(context: ChannelHandlerContext) {
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      let frame = self.unwrapInboundIn(data)

      switch frame.opcode {
      case .connectionClose:
        self.receivedClose(context: context, frame: frame)
      case .text:
        var data = frame.unmaskedData
        let text = data.readString(length: data.readableBytes) ?? ""
        self.configuration.onText(text)
      case .binary, .continuation, .pong:
        // We ignore these frames.
        break
      default:
        // Unknown frames are errors.
        self.closeOnError(context: context)
      }
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
      context.flush()
    }

    private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
      if awaitingClose {
        context.close(promise: nil)
      } else {
        var data = frame.unmaskedData
        let closeDataCode = data.readSlice(length: 2) ?? ByteBuffer()
        let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, data: closeDataCode)
        _ = context.write(self.wrapOutboundOut(closeFrame)).map { () in
          context.close(promise: nil)
        }
      }
    }

    private func closeOnError(context: ChannelHandlerContext) {
      var data = context.channel.allocator.buffer(capacity: 2)
      data.write(webSocketErrorCode: .protocolError)
      let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
      context.write(self.wrapOutboundOut(frame)).whenComplete { (_: Result<Void, Error>) in
        context.close(mode: .output, promise: nil)
      }
      awaitingClose = true
    }
  }
}

extension ChannelHandlerContext: @unchecked Sendable {}
