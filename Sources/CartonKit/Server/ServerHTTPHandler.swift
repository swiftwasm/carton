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
import NIO
import NIOHTTP1

final class ServerHTTPHandler: ChannelInboundHandler, RemovableChannelHandler {
  typealias InboundIn = HTTPServerRequestPart
  typealias OutboundOut = HTTPServerResponsePart

  struct Configuration {
    let logger: Logger
    let mainWasmPath: AbsolutePath
    let customIndexPath: AbsolutePath?
    let resourcesPaths: [String]
    let entrypoint: Entrypoint
    let serverName: String
    let env: [String: String]?
  }

  struct ServerError: Error, CustomStringConvertible {
    let description: String
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
    let constructBody: (StaticResponse) throws -> ByteBuffer
    // GET or HEAD only.
    switch head.method {
    case .GET:
      constructBody = { response in
        try response.readBody()
      }
    case .HEAD:
      constructBody = { _ in ByteBuffer() }
    default:
      self.respondEmpty(context: context, status: .methodNotAllowed)
      return
    }

    let configuration = self.configuration
    configuration.logger.info("\(head.method) \(head.uri)")

    let response: StaticResponse
    let body: ByteBuffer
    do {
      switch head.uri {
      case "/":
        response = try respondIndexPage(context: context)
      case "/main.wasm":
        let contentSize = try localFileSystem.getFileInfo(configuration.mainWasmPath).size
        response = StaticResponse(
          contentType: "application/wasm", contentSize: Int(contentSize),
          body: try context.channel.allocator.buffer(
            bytes: localFileSystem.readFileContents(configuration.mainWasmPath).contents
          )
        )
      case "/process-info.json":
        response = try respondProcessInfo(context: context)
      case "/" + configuration.entrypoint.fileName:
        response = StaticResponse(
          contentType: "application/javascript",
          contentSize: configuration.entrypoint.content.count,
          body: ByteBuffer(bytes: configuration.entrypoint.content.contents)
        )
      default:
        guard let staticResponse = try self.respond(context: context, head: head) else {
          self.respondEmpty(context: context, status: .notFound)
          return
        }
        response = staticResponse
      }
      body = try constructBody(response)
    } catch {
      configuration.logger.error("Failed to respond to \(head.uri): \(error)")
      self.respondEmpty(context: context, status: .internalServerError)
      return
    }

    var headers = HTTPHeaders()
    headers.add(name: "Server", value: configuration.serverName)
    headers.add(name: "Content-Type", value: response.contentType)
    headers.add(name: "Content-Length", value: String(response.contentSize))
    headers.add(name: "Connection", value: "close")
    let responseHead = HTTPResponseHead(
      version: .http1_1,
      status: .ok,
      headers: headers)
    context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
    context.write(self.wrapOutboundOut(.body(.byteBuffer(body))), promise: nil)
    context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
      context.close(promise: nil)
    }
    context.flush()
  }

  struct StaticResponse {
    let contentType: String
    let contentSize: Int
    private let _body: () throws -> ByteBuffer

    init(contentType: String, contentSize: Int, body: @autoclosure @escaping () throws -> ByteBuffer) {
      self.contentType = contentType
      self.contentSize = contentSize
      self._body = body
    }

    func readBody() throws -> ByteBuffer {
      return try self._body()
    }
  }

  private func respond(context: ChannelHandlerContext, head: HTTPRequestHead) throws
  -> StaticResponse?
  {
    var responders: [(_ context: ChannelHandlerContext, _ uri: String) throws -> StaticResponse?] = []

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

    guard let uri = head.uri.removingPercentEncoding else {
      configuration.logger.error("Failed to percent decode uri: \(head.uri)")
      return nil
    }
    for responder in responders {
      if let response = try responder(context, uri) {
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
      let contentType = contentType(of: fileURL) ?? "application/octet-stream"
      let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
      guard let contentSize = (attributes[.size] as? NSNumber)?.intValue else {
        throw ServerError(description: "Failed to get content size of \(fileURL)")
      }

      return StaticResponse(
        contentType: contentType, contentSize: contentSize,
        body: try context.channel.allocator.buffer(bytes: Data(contentsOf: fileURL))
      )
    }
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
      contentType: "text/html", contentSize: htmlContent.utf8.count,
      body: context.channel.allocator.buffer(string: htmlContent)
    )
  }

  private func respondProcessInfo(context: ChannelHandlerContext) throws -> StaticResponse {
    struct ProcessInfoBody: Encodable {
      let env: [String: String]?
    }
    let config = ProcessInfoBody(env: configuration.env)
    let json = try JSONEncoder().encode(config)
    return StaticResponse(
      contentType: "application/json", contentSize: json.count,
      body: context.channel.allocator.buffer(bytes: json)
    )
  }

  private func respondEmpty(context: ChannelHandlerContext, status: HTTPResponseStatus) {
    var headers = HTTPHeaders()
    headers.add(name: "Connection", value: "close")
    headers.add(name: "Content-Length", value: "0")
    let head = HTTPResponseHead(
      version: .http1_1,
      status: status,
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
