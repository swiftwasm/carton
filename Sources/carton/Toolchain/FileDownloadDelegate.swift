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

final class FileDownloadDelegate: HTTPClientResponseDelegate {
  typealias Response = (totalBytes: Int?, receivedBytes: Int)

  private var totalBytes: Int?
  private var receivedBytes = 0

  private let handle: NIOFileHandle
  private let io: NonBlockingFileIO
  private let reportProgress: (_ totalBytes: Int?, _ receivedBytes: Int) -> ()

  private var writeFuture: EventLoopFuture<()>?

  init(
    path: String,
    reportProgress: @escaping (_ totalBytes: Int?, _ receivedBytes: Int) -> ()
  ) throws {
    handle = try NIOFileHandle(path: path, mode: .write, flags: .allowFileCreation())
    let pool = NIOThreadPool(numberOfThreads: 1)
    pool.start()
    io = NonBlockingFileIO(threadPool: pool)

    self.reportProgress = reportProgress
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
    receivedBytes += buffer.readableBytes
    reportProgress(totalBytes, receivedBytes)

    let writeFuture = io.write(fileHandle: handle, buffer: buffer, eventLoop: task.eventLoop)
    self.writeFuture = writeFuture
    return writeFuture
  }

  func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Response {
    writeFuture?.whenComplete { [weak self] _ in
      try? self?.handle.close()
      self?.writeFuture = nil
    }
    return (totalBytes, receivedBytes)
  }
}
