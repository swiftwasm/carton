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
#else

// Due to a broken URLSession in swift-corelibs-foundation, this class cannot be used on Linux.
public struct URLSessionWebDriverHTTPClient: WebDriverHTTPClient {
  public init(session: URLSession) {
    self.session = session
  }

  public var session: URLSession

  public func data(for request: URLRequest) async throws -> Data {
    let (data, httpResponse) = try await session.data(for: request)
    guard let httpResponse = httpResponse as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode
    else {
      throw WebDriverError.httpError(
        "\(request.httpMethod ?? "GET") \(request.url.debugDescription) failed"
      )
    }
    return data
  }
}

#endif
