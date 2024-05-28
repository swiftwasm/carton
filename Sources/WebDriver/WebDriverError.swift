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

public enum WebDriverError: Error & CustomStringConvertible {
  case invalidRemoteURL(String)
  case failedToFindWebDriver
  case failedToFindHTTPClient
  case curlError(path: URL, status: Int32, body: String?)
  case httpError(String)

  public var description: String {
    switch self {
    case .invalidRemoteURL(let url): return "invalid remote webdriver URL: \(url)"
    case .curlError(path: let path, status: let status, body: let body):
      var lines: [String] = [
        "\(path.path) failed with status \(status)."
      ]

      if let body {
        lines += [
          "body:", body
        ]
      }

      return lines.joined(separator: "\n")
    case .failedToFindWebDriver:
      return """
      Failed to find WebDriver executable or remote URL to a running driver process.
      Please make sure that you are satisfied with one of the followings (in order of priority)
      1. Set `WEBDRIVER_REMOTE_URL` with the address of remote WebDriver like `WEBDRIVER_REMOTE_URL=http://localhost:9515`.
      2. Set `WEBDRIVER_PATH` with the path to your WebDriver executable.
      3. `chromedriver`, `geckodriver`, `safaridriver`, or `msedgedriver` has been installed in `PATH`
      """
    case .failedToFindHTTPClient:
      return """
      The HTTPClient for use with WebDriver could not be found.
      On Linux, please ensure that curl is installed.
      On Mac, URLSession can be used, so this error should not appear.
      If this error is displayed, an unknown bug may have occurred.
      """
    case .httpError(let string): return "http error: \(string)"
    }
  }
}
