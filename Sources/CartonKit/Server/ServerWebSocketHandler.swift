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
import NIO
import NIOWebSocket

final class ServerWebSocketHandler: ChannelInboundHandler {
  typealias InboundIn = WebSocketFrame
  typealias OutboundOut = WebSocketFrame

  struct Configuration {
    var onText: @Sendable (String) -> Void
    var onBinary: @Sendable (Data) -> Void
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
    case .binary:
      let nioData = frame.unmaskedData
      let data = Data(nioData.readableBytesView)
      self.configuration.onBinary(data)
    case .continuation, .pong:
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
