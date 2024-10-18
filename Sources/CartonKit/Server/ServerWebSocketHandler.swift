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
import FlyingFox
import CartonHelpers

private enum Event {
  enum CodingKeys: String, CodingKey {
    case kind
    case stackTrace
    case testRunOutput
    case errorReport
  }

  enum Kind: String, Decodable {
    case stackTrace
    case testRunOutput
    case testPassed
    case errorReport
  }

  case stackTrace(String)
  case testRunOutput(String)
  case testPassed
  case errorReport(String)
}

extension Event: Decodable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let kind = try container.decode(Kind.self, forKey: .kind)

    switch kind {
    case .stackTrace:
      let rawStackTrace = try container.decode(String.self, forKey: .stackTrace)
      self = .stackTrace(rawStackTrace)
    case .testRunOutput:
      let output = try container.decode(String.self, forKey: .testRunOutput)
      self = .testRunOutput(output)
    case .testPassed:
      self = .testPassed
    case .errorReport:
      let output = try container.decode(String.self, forKey: .errorReport)
      self = .errorReport(output)
    }
  }
}

struct ServerWebSocketHandler: HTTPHandler {
  let server: Server

  func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
    let userAgent = request.headers[HTTPHeader(rawValue: "User-Agent")]
    let environment: DestinationEnvironment = if let userAgent {
      DestinationEnvironment(userAgent: userAgent) ?? .other
    } else {
      .other
    }
    
    let underlying = WebSocketHTTPHandler(
      handler: MessageFrameWSHandler(
        handler: WSHandler(environment: environment, server: server),
        frameSize: .max
      )
    )
    return try await underlying.handleRequest(request)
  }
  
  struct WSHandler: WSMessageHandler {
    let environment: DestinationEnvironment
    let server: Server
    /// Used for decoding `Event` values sent from the WebSocket client.
    private let decoder = JSONDecoder()
    
    func makeMessages(for client: AsyncStream<WSMessage>) async throws -> AsyncStream<WSMessage> {
      let (response, continuation) = AsyncStream<WSMessage>.makeStream()
      let connection = Server.Connection(channel: continuation)
      let subscription = Task {
        for await message in client {
          switch message {
          case .text(let text):
            self.webSocketTextHandler(text: text, environment: environment)
          case .data(let data):
            self.webSocketBinaryHandler(data: data)
          }
        }
        await server.remove(connection: connection)
      }
      continuation.onTermination = { _ in
        subscription.cancel()
      }
      await server.add(connection: connection)
      return response
    }
    
    /// Respond to WebSocket messages coming from the browser.
    func webSocketTextHandler(
      text: String,
      environment: DestinationEnvironment
    ) {
      guard
        let data = text.data(using: .utf8),
        let event = try? self.decoder.decode(Event.self, from: data)
      else {
        return
      }
      
      let terminal = server.configuration.terminal
      
      switch event {
      case let .stackTrace(rawStackTrace):
        if let stackTrace = rawStackTrace.parsedStackTrace(in: environment) {
          terminal.write("\nAn error occurred, here's a stack trace for it:\n", inColor: .red)
          stackTrace.forEach { item in
            terminal.write("  \(item.symbol)", inColor: .cyan)
            terminal.write(" at \(item.location ?? "<unknown>")\n", inColor: .gray)
          }
        } else {
          terminal.write("\nAn error occurred, here's the raw stack trace for it:\n", inColor: .red)
          terminal.write(
            "  Please create an issue or PR to the Carton repository\n"
            + "  with your browser name and this raw stack trace so\n"
            + "  we can add support for it: https://github.com/swiftwasm/carton\n", inColor: .gray
          )
          terminal.write(rawStackTrace + "\n")
        }
        
      case let .testRunOutput(output):
        TestsParser().parse(output, terminal)
        
      case .testPassed:
        Task { await server.stopTest(hadError: false) }
        
      case let .errorReport(output):
        terminal.write("\nAn error occurred:\n", inColor: .red)
        terminal.write(output + "\n")
        
        Task { await server.stopTest(hadError: true) }
      }
    }
    
    private static func decodeLines(data: Data) -> [String] {
      let text = String(decoding: data, as: UTF8.self)
      return text.components(separatedBy: .newlines)
    }
    
    func webSocketBinaryHandler(data: Data) {
      let terminal = server.configuration.terminal
      
      if data.count < 2 {
        return
      }
      
      var kind: UInt16 = 0
      _ = withUnsafeMutableBytes(of: &kind) { (buffer) in
        data.copyBytes(to: buffer, from: 0..<2)
      }
      kind = UInt16(littleEndian: kind)
      
      switch kind {
      case 1001:
        // stdout
        let chunk = data.subdata(in: 2..<data.count)
        if chunk.isEmpty { return }
        
        for line in Self.decodeLines(data: chunk) {
          terminal.write("stdout: " + line + "\n")
        }
      case 1002:
        // stderr
        let chunk = data.subdata(in: 2..<data.count)
        if chunk.isEmpty { return }
        
        for line in Self.decodeLines(data: chunk) {
          terminal.write("stderr: " + line + "\n", inColor: .red)
        }
      default: break
      }
    }
  }
}
