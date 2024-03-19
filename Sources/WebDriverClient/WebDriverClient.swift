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

  /// Until we get "async" implementations of URLSession in corelibs-foundation, we use our own polyfill.
  extension URLSession {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      return try await withCheckedThrowingContinuation { continuation in
        let task = self.dataTask(with: request) { (data, response, error) in
          guard let data = data, let response = response else {
            let error = error ?? URLError(.badServerResponse)
            return continuation.resume(throwing: error)
          }
          continuation.resume(returning: (data, response))
        }
        task.resume()
      }
    }
  }
#endif

public enum WebDriverError: Error {
  case httpError(String)
}

public struct WebDriverClient {
  private let client: WebDriverHTTPClient
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
          },
          "ms:edgeOptions": {
            "args": ["--headless", "--no-sandbox"]
          }
        }
      }
    }
    """#

  public static func newSession(
    endpoint: URL, body: String = defaultSessionRequestBody,
    httpClient: URLSession
  ) async throws -> WebDriverClient {
    struct Response: Decodable {
      let sessionId: String
    }
    struct Request: Encodable {
      let capabilities: [String: String] = [:]
      let desiredCapabilities: [String: String] = [:]
    }
    let httpClient: WebDriverHTTPClient = Curl.findExecutable() ?? httpClient
    var request = URLRequest(url: endpoint.appendingPathComponent("session"))
    request.httpMethod = "POST"
    request.httpBody = body.data(using: .utf8)
    let body = try await httpClient.data(for: request)
    let decoder = JSONDecoder()
    let response = try decoder.decode(ValueResponse<Response>.self, from: body)
    return WebDriverClient(
      client: httpClient,
      driverEndpoint: endpoint,
      sessionId: response.sessionId)
  }

  private func makeSessionURL(_ components: String...) -> String {
    var url =
      driverEndpoint
      .appendingPathComponent("session")
      .appendingPathComponent(sessionId)
    for component in components {
      url.appendPathComponent(component)
    }
    return url.absoluteString
  }

  private static func makeRequestBody<R: Encodable>(_ body: R) throws -> Data {
    let encoder = JSONEncoder()
    return try encoder.encode(body)
  }

  public func goto(url: String) async throws {
    struct Request: Encodable {
      let url: String
    }
    var request = URLRequest(url: URL(string: makeSessionURL("url"))!)
    request.httpMethod = "POST"
    request.httpBody = try Self.makeRequestBody(Request(url: url))
    request.addValue("carton", forHTTPHeaderField: "User-Agent")
    _ = try await client.data(for: request)
  }

  public func closeSession() async throws {
    var request = URLRequest(url: URL(string: makeSessionURL())!)
    request.httpMethod = "DELETE"
    _ = try await client.data(for: request)
  }
}


private protocol WebDriverHTTPClient {
  func data(for request: URLRequest) async throws -> Data
}

extension URLSession: WebDriverHTTPClient {
  func data(for request: URLRequest) async throws -> Data {
    let (data, httpResponse) = try await self.data(for: request)
    guard let httpResponse = httpResponse as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode
    else {
      throw WebDriverError.httpError(
        "\(request.httpMethod ?? "GET") \(request.url.debugDescription) failed"
      )
    }
    return data
  }
}

private struct Curl: WebDriverHTTPClient {
  let cliPath: URL

  static func findExecutable() -> Curl? {
    guard let path = ProcessInfo.processInfo.environment["PATH"] else { return nil }
    #if os(Windows)
    let pathSeparator: Character = ";"
    #else
    let pathSeparator: Character = ":"
    #endif
    for pathEntry in path.split(separator: pathSeparator) {
      let candidate = URL(fileURLWithPath: String(pathEntry)).appending(path: "curl")
      if FileManager.default.fileExists(atPath: candidate.path) {
        return Curl(cliPath: candidate)
      }
    }
    return nil
  }

  func data(for request: URLRequest) async throws -> Data {
    guard let url = request.url?.absoluteString else {
      preconditionFailure()
    }
    let process = Process()
    process.executableURL = cliPath
    process.arguments = [
      url, "-X", request.httpMethod ?? "GET", "--silent", "--fail-with-body", "--data-binary", "@-"
    ]
    let stdout = Pipe()
    let stdin = Pipe()
    process.standardOutput = stdout
    process.standardInput = stdin
    if let httpBody = request.httpBody {
      try stdin.fileHandleForWriting.write(contentsOf: httpBody)
    }
    try stdin.fileHandleForWriting.close()
    try process.run()
    process.waitUntilExit()
    let responseBody = try stdout.fileHandleForReading.readToEnd()
    guard process.terminationStatus == 0 else {
      throw WebDriverError.httpError(
        responseBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
      )
    }
    return responseBody ?? Data()
  }
}
