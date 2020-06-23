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

import AsyncHTTPClient
import NIO
import NIOHTTP1

final class ResponseDelegate: HTTPClientResponseDelegate {
  typealias Response = (totalBytes: Int, receivedBytes: Int)

  private var totalBytes: Int
  private var receivedBytes = 0

  init(expectedBytes: Int) {
    totalBytes = expectedBytes
  }

  func didReceiveHead(
    task: HTTPClient.Task<Response>,
    _ head: HTTPResponseHead
  ) -> EventLoopFuture<()> {
    if let totalBytesString = head.headers.first(name: "Content-Length"),
      let totalBytes = Int(totalBytesString) {
      self.totalBytes = totalBytes
    }

    return task.eventLoop.makeSucceededFuture(())
  }

  func didReceiveBodyPart(
    task: HTTPClient.Task<Response>,
    _ buffer: ByteBuffer
  ) -> EventLoopFuture<()> {
    task.eventLoop.makeSucceededFuture(())
  }

  func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {}

  func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Response {
    (totalBytes, receivedBytes)
  }
}
