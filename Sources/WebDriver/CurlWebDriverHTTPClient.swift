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

public struct CurlWebDriverHTTPClient: WebDriverHTTPClient {
  public init(cliPath: URL) {
    self.cliPath = cliPath
  }

  public var cliPath: URL

  public static func find() -> CurlWebDriverHTTPClient? {
    guard let path = ProcessInfo.processInfo.environment["PATH"] else { return nil }
    #if os(Windows)
    let pathSeparator: Character = ";"
    #else
    let pathSeparator: Character = ":"
    #endif
    for pathEntry in path.split(separator: pathSeparator) {
      let candidate = URL(fileURLWithPath: String(pathEntry)).appendingPathComponent("curl")
      if FileManager.default.fileExists(atPath: candidate.path) {
        return CurlWebDriverHTTPClient(cliPath: candidate)
      }
    }
    return nil
  }

  public func data(for request: URLRequest) async throws -> Data {
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
      let body: String? = responseBody.map { String(decoding: $0, as: UTF8.self) }

      throw WebDriverError.curlError(
        path: cliPath, 
        status: process.terminationStatus,
        body: body
      )
    }
    return responseBody ?? Data()
  }
}
