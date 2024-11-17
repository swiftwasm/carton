// Copyright 2022 Carton contributors
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

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct InvalidResponseCode: Error {
  let code: UInt

  var description: String {
    """
    While attempting to download an archive, the server returned an invalid response code \(code)
    """
  }
}

public final class AsyncFileDownload {
  public struct Progress: Sendable {
    public var totalBytes: Int?
    public var receivedBytes: Int
  }
  class FileDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let path: String
    let onTotalBytes: (Int) -> Void
    let continuation: AsyncThrowingStream<Progress, Error>.Continuation
    var totalBytesToDownload: Int?

    init(
      path: String,
      onTotalBytes: @escaping (Int) -> Void,
      continuation: AsyncThrowingStream<Progress, Error>.Continuation
    ) {
      self.path = path
      self.onTotalBytes = onTotalBytes
      self.continuation = continuation
    }

    func urlSession(
      _ session: URLSession,
      downloadTask: URLSessionDownloadTask,
      didWriteData bytesWritten: Int64,
      totalBytesWritten: Int64,
      totalBytesExpectedToWrite: Int64
    ) {
      let totalBytesToDownload =
        totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown
        ? Int(totalBytesExpectedToWrite) : nil
      if self.totalBytesToDownload == nil {
        self.totalBytesToDownload = totalBytesToDownload
        self.onTotalBytes(totalBytesToDownload ?? .max)
      }
      continuation.yield(
        AsyncFileDownload.Progress(
          totalBytes: totalBytesToDownload,
          receivedBytes: Int(totalBytesWritten)
        )
      )
    }

    func urlSession(
      _ session: URLSession, downloadTask: URLSessionDownloadTask,
      didFinishDownloadingTo location: URL
    ) {
      do {
        try FileManager.default.moveItem(atPath: location.path, toPath: self.path)
        continuation.finish()
      } catch {
        continuation.finish(throwing: error)
      }
    }
  }

  public var progressStream: AsyncThrowingStream<Progress, Error> {
    _progressStream
  }
  private var _progressStream: AsyncThrowingStream<Progress, Error>!
  private var client: URLSession! = nil

  public init(path: String, _ url: URL, onTotalBytes: @escaping (Int) -> Void) {
    _progressStream = .init { continuation in
      let delegate = FileDownloadDelegate(
        path: path,
        onTotalBytes: onTotalBytes,
        continuation: continuation
      )
      self.client = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
      var request = URLRequest(url: url)
      request.httpMethod = "GET"
      client.downloadTask(with: request).resume()
    }
  }
}
