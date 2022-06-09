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

public enum WebDriverError: Error {
  case newSessionFailed(HTTPClient.Response)
}

public struct WebDriverClient {
  let client: HTTPClient
  let driverEndpoint: URL
  let sessionId: String

  @dynamicMemberLookup
  struct ValueResponse<Value: Decodable>: Decodable {
    let value: Value
    subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
      self.value[keyPath: keyPath]
    }
  }

  public static let defaultSessionRequestBody = #"""
  {
    "capabilities": {
      "alwaysMatch": {
        "goog:chromeOptions": {
          "w3c": true,
          "args": ["--headless", "--no-sandbox"]
        },
        "moz:firefoxOptions": {
          "args": ["-headless"]
        }
      }
    }
  }
  """#

  public static func newSession(endpoint: URL, body: String = defaultSessionRequestBody,
                                httpClient: HTTPClient) async throws -> WebDriverClient
  {
    struct Response: Decodable {
      let sessionId: String
    }
    struct Request: Encodable {
      let capabilities: [String: String] = [:]
      let desiredCapabilities: [String: String] = [:]
    }
    let httpResponse = try await httpClient.post(
      url: endpoint.appendingPathComponent("session").absoluteString,
      body: HTTPClient.Body.string(body)
    ).get()
    guard let responseBody = httpResponse.body else {
      throw WebDriverError.newSessionFailed(httpResponse)
    }
    let decoder = JSONDecoder()
    let response = try decoder.decode(ValueResponse<Response>.self, from: responseBody)
    return WebDriverClient(client: httpClient,
                           driverEndpoint: endpoint,
                           sessionId: response.sessionId)
  }

  private func makeSessionURL(_ components: String...) -> String {
    var url = driverEndpoint
      .appendingPathComponent("session")
      .appendingPathComponent(sessionId)
    for component in components {
      url.appendPathComponent(component)
    }
    return url.absoluteString
  }

  private static func makeRequestBody<R: Encodable>(_ body: R) throws -> HTTPClient.Body {
    let encoder = JSONEncoder()
    return try HTTPClient.Body.data(encoder.encode(body))
  }

  public func goto(url: String) async throws {
    struct Response: Decodable {}
    struct Request: Encodable {
      let url: String
    }
    _ = try await client.post(
      url: makeSessionURL("url"),
      body: Self.makeRequestBody(Request(url: url))
    )
    .get()
  }

  public func closeSession() async throws {
    _ = try await client.delete(url: makeSessionURL()).get()
  }
}
