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

import AsyncHTTPClient
import Foundation

public struct InvalidResponseCode: Error {
  let code: UInt

  var description: String {
    """
    While attempting to download an archive, the server returned an invalid response code \(code)
    """
  }
}

public final class AsyncFileDownload {
  public let progressStream: AsyncThrowingStream<FileDownloadDelegate.Progress, Error>

  public init(path: String, _ url: URL, _ client: HTTPClient, onTotalBytes: @escaping (Int) -> ()) {
    progressStream = .init { continuation in
      do {
        let request = try HTTPClient.Request.get(url: url)

        let delegate = try FileDownloadDelegate(
          path: path,
          reportHead: {
            guard $0.status == .ok,
                  let totalBytes = $0.headers.first(name: "Content-Length").flatMap(Int.init)
            else {
              continuation
                .finish(throwing: InvalidResponseCode(code: $0.status.code))
              return
            }
            onTotalBytes(totalBytes)
          },
          reportProgress: {
            continuation.yield($0)
          }
        )

        Task {
          _ = try await client.execute(request: request, delegate: delegate)
            .futureResult
            .get()

          continuation.finish()
        }
      } catch {
        continuation.finish(throwing: error)
      }
    }
  }
}
