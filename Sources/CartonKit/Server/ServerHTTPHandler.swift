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

import CartonHelpers
import Foundation
import Logging
import FlyingFox

extension Server {
  private func makeHeaders(_ headers: [HTTPHeader: String]) -> [HTTPHeader: String] {
    var headers = headers
    headers[HTTPHeader(rawValue: "Server")] = self.serverName.description
    return headers
  }

  func respondIndexPage(_ request: HTTPRequest) throws -> HTTPResponse {
    var customIndexContent: String?
    if let path = configuration.customIndexPath?.pathString {
      customIndexContent = try String(contentsOfFile: path)
    }
    let htmlContent = HTML.indexPage(
      customContent: customIndexContent,
      entrypointName: configuration.entrypoint.fileName
    )
    return HTTPResponse(
      statusCode: .ok,
      headers: makeHeaders([
        .contentType: "text/html"
      ]),
      body: HTTPBodySequence(data: htmlContent.data(using: .utf8)!)
    )
  }

  func respondEntrypoint(_ request: HTTPRequest, entrypoint: Entrypoint) throws -> HTTPResponse {
    return HTTPResponse(
      statusCode: .ok,
      headers: makeHeaders([
        .contentType: "application/javascript",
      ]),
      body: HTTPBodySequence(data: Data(entrypoint.content.contents))
    )
  }

  func respondProcessInfo(_ request: HTTPRequest) throws -> HTTPResponse {
    struct ProcessInfoBody: Encodable {
      let env: [String: String]?
    }
    let config = ProcessInfoBody(env: configuration.env)
    let json = try JSONEncoder().encode(config)
    return HTTPResponse(
      statusCode: .ok,
      headers: makeHeaders([
        .contentType: "application/json"
      ]),
      body: json
    )
  }
}
