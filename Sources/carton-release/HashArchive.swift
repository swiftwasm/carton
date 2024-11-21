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

import ArgumentParser
import CartonCore
import Foundation

struct HashArchive: AsyncParsableCommand {
  /** Converts a hexadecimal hash string to Swift code that represents an archive of static assets.
   */
  private func arrayString(from hash: String) -> String {
    precondition(hash.count == 64)

    let commaSeparated = stride(from: 0, to: hash.count, by: 2)
      .map { "0x\(hash.dropLast(hash.count - $0 - 2).suffix(2))" }
      .joined(separator: ", ")

    precondition(commaSeparated.count == 190)

    return """
        \(commaSeparated.prefix(95))
        \(commaSeparated.suffix(94))
      """
  }

  func run() async throws {
    let staticPath = URL(fileURLWithPath: "static")

    var fileContent = """
      import Foundation

      public enum StaticResource {

      """

    for entrypoint in ["dev", "bundle", "intrinsics"] {
      let tsFilename = "\(entrypoint).ts"
      let filename = "\(entrypoint).js"
      let arguments = [
        "esbuild", "--bundle", "entrypoint/\(tsFilename)", "--outfile=static/\(filename)",
        "--external:node:url", "--external:node:path",
        "--external:node:module", "--external:node:http",
        "--external:node:fs/promises", "--external:node:fs",
        "--external:playwright",
        "--format=esm",
        "--external:./JavaScriptKit_JavaScriptKit.resources/Runtime/index.mjs",
      ]

      let npx = try Process.which("npx")
      try Foundation.Process.run(npx, arguments: arguments).waitUntilExit()
      let entrypointPath = URL(fileURLWithPath: filename, relativeTo: staticPath)

      // Base64 is not an efficient way, but too long byte array literal breaks type-checker
      let base64Content = try Data(contentsOf: entrypointPath).base64EncodedString()
      fileContent += """
          public static let \(entrypoint): Data = Data(base64Encoded: \"\(base64Content)\")!

        """
    }

    fileContent += """

      }
      """

    try fileContent.write(
      toFile: "Sources/CartonHelpers/StaticArchive.swift", atomically: true, encoding: .utf8)
  }
}
