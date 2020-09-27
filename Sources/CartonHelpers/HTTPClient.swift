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
import Foundation

public extension HTTPClient.Request {
  static func get(url: URL) throws -> Self {
    try get(url: url.absoluteString)
  }

  static func get(url: String) throws -> Self {
    var request = try HTTPClient.Request(url: url)
    request.headers.add(name: "User-Agent", value: "carton \(cartonVersion)")
    if let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] {
      request.headers.add(name: "Authorization", value: "Bearer \(token)")
    }
    return request
  }
}
