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

enum ToolchainError: Error, CustomStringConvertible {
  case directoryDoesNotExist(AbsolutePath)
  case invalidInstallationArchive(AbsolutePath)
  case invalidVersion(version: String)
  case invalidResponse(url: String, status: Int)
  case unsupportedOperatingSystem
  case noInstallationDirectory(path: String)

  var description: String {
    switch self {
    case let .directoryDoesNotExist(path):
      return "Directory at path \(path.pathString) does not exist and could not be created"
    case let .invalidInstallationArchive(path):
      return "Invalid toolchain/SDK archive was installed at path \(path)"
    case let .invalidVersion(version):
      return "Invalid version \(version)"
    case let .invalidResponse(url: url, status: status):
      return "Response from \(url) had invalid status \(status) or didn't contain body"
    case .unsupportedOperatingSystem:
      return "This version of the operating system is not supported"
    case let .noInstallationDirectory(path):
      return """
        Failed to infer toolchain installation directory. Please make sure that \(path) exists.
        """
    }
  }
}
