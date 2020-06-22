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

import Foundation
import TSCBasic

/**
 Simple Package structure from package dump
 */
struct Package: Codable {
  let name: String
  let products: [Product]
  let targets: [Target]

  init(with swiftPath: String, _ terminal: TerminalController) throws {
    terminal.write("Parsing package manifest: ", inColor: .yellow)
    terminal.write("\(swiftPath) package dump-package\n")
    let output = try Data(processDataOutput([swiftPath, "package", "dump-package"]))

    self = try JSONDecoder().decode(Package.self, from: output)
  }

  func inferDevProduct(
    with swiftPath: String,
    option: String?,
    _ terminal: TerminalController
  ) -> String? {
    var candidateProducts = products
      .filter { $0.type.library == nil }
      .map(\.name)

    if let product = option {
      candidateProducts = candidateProducts.filter { $0 == product }

      guard candidateProducts.count == 1 else {
        terminal.write("""
        Failed to disambiguate the executable product, \
        make sure `\(product)` product is present in Package.swift
        """, inColor: .red)
        return nil
      }

      terminal.logLookup("- development product: ", product)
      return product
    } else if candidateProducts.count == 1 {
      return candidateProducts[0]
    } else {
      terminal.write("Failed to disambiguate the development product\n", inColor: .red)

      if candidateProducts.count > 1 {
        terminal.write("Pass one of \(candidateProducts) to the --product option\n", inColor: .red)
      } else {
        terminal.write(
          "Make sure there's at least one executable product in your Package.swift\n",
          inColor: .red
        )
      }

      return nil
    }
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
}
