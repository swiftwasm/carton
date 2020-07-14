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
struct Package: Codable {
  let name: String
  let products: [Product]
  let targets: [Target]

  init(with swiftPath: AbsolutePath, _ terminal: TerminalController) throws {
    terminal.write("\nParsing package manifest: ", inColor: .yellow)
    terminal.write("\(swiftPath) package dump-package\n")
    let output = try Data(processDataOutput([swiftPath.pathString, "package", "dump-package"]))

    self = try JSONDecoder().decode(Package.self, from: output)
  }
}

struct ProductType: Codable {
  let executable: String?
  let library: [String]?
}

/**
 Simple Product structure from package dump
 */
struct Product: Codable {
  let name: String
  let type: ProductType
}

enum TargetType: String, Codable {
  case regular
  case test
}

struct Target: Codable {
  let name: String
  let type: TargetType
  let path: String?
}
