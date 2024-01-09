//// Copyright 2020 Carton contributors
////
//// Licensed under the Apache License, Version 2.0 (the "License");
//// you may not use this file except in compliance with the License.
//// You may obtain a copy of the License at
////
////     http://www.apache.org/licenses/LICENSE-2.0
////
//// Unless required by applicable law or agreed to in writing, software
//// distributed under the License is distributed on an "AS IS" BASIS,
//// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//// See the License for the specific language governing permissions and
//// limitations under the License.

import CartonHelpers

public let compatibleJSKitVersion = "0.18.0"

enum ToolchainError: Error, CustomStringConvertible {
  case directoryDoesNotExist(AbsolutePath)
  case invalidInstallationArchive(AbsolutePath)
  case noExecutableProduct
  case failedToBuild(product: String)
  case failedToBuildTestBundle
  case missingPackageManifest
  case invalidVersion(version: String)
  case invalidResponse(url: String, status: Int)
  case unsupportedOperatingSystem
  case noInstallationDirectory(path: String)
  case noWorkingDirectory

  var description: String {
    switch self {
    case let .directoryDoesNotExist(path):
      return "Directory at path \(path.pathString) does not exist and could not be created"
    case let .invalidInstallationArchive(path):
      return "Invalid toolchain/SDK archive was installed at path \(path)"
    case .noExecutableProduct:
      return "No executable product to build could be inferred"
    case let .failedToBuild(product):
      return "Failed to build executable product \(product)"
    case .failedToBuildTestBundle:
      return "Failed to build the test bundle"
    case .missingPackageManifest:
      return """
        The `Package.swift` manifest file could not be found. Please navigate to a directory that \
        contains `Package.swift` and restart.
        """
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
    case .noWorkingDirectory:
      return "Working directory cannot be inferred from file system"
    }
  }
}
