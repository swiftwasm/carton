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
import TSCBasic

/**
 Simple Package structure from package dump
 */
public struct Package: Codable {
  public let name: String
  public let products: [Product]
  public let targets: [Target]
  public let dependencies: [Dependency]?

  public struct Dependency: Codable {
    let name: String
    let requirement: Requirement

    struct Requirement: Codable {
      let range: [Range]?
      let branch: [String]?
      let revision: [String]?
      let exact: [String]?

      struct Range: Codable {
        let lowerBound: String
        let upperBound: String
      }
    }
  }

  init(with swiftPath: AbsolutePath, _ terminal: TerminalController) throws {
    terminal.write("\nParsing package manifest: ", inColor: .yellow)
    terminal.write("\(swiftPath) package dump-package\n")
    let output = try Data(processDataOutput([swiftPath.pathString, "package", "dump-package"]))

    self = try JSONDecoder().decode(Package.self, from: output)
  }

  public func resourcesPath(for target: Target) -> String {
    "\(name)_\(target.name).resources"
  }
}

struct ProductType: Codable {
  let executable: String?
  let library: [String]?
}

/**
 Simple Product structure from package dump
 */
public struct Product: Codable {
  let name: String
  let type: ProductType
}

public enum TargetType: String, Codable {
  case regular
  case test
}

public struct Target: Codable {
  public let name: String
  public let type: TargetType
  public let path: String?
  public let resources: [Resource]
}

public struct Resource: Codable {
  public let path: String
  public let rule: Rule

  public enum Rule: String, Codable {
    case copy
    case process
  }
}

public enum PackageType: String {
  case empty
  case library
  case executable
  case systemModule = "system-module"
  case manifest
}
