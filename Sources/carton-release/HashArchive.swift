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
import CartonHelpers
import TSCBasic
import WasmTransformer

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
    let terminal = InteractiveWriter.stdout
    let cwd = localFileSystem.currentWorkingDirectory!
    let staticPath = AbsolutePath(cwd, "static")
    let dotFilesStaticPath = localFileSystem.homeDirectory.appending(
      components: ".carton",
      "static"
    )

    try localFileSystem.createDirectory(dotFilesStaticPath, recursive: true)
    let hashes = try await ["dev", "bundle", "test", "testNode"].asyncMap { entrypoint -> (String, String) in
      try await Process.run(["npm", "run", entrypoint], terminal)
      let entrypointPath = AbsolutePath(staticPath, "\(entrypoint).js")
      let dotFilesEntrypointPath = dotFilesStaticPath.appending(component: "\(entrypoint).js")
      try localFileSystem.removeFileTree(dotFilesEntrypointPath)
      try localFileSystem.copy(from: entrypointPath, to: dotFilesEntrypointPath)

      return (entrypoint, try SHA256().hash(localFileSystem.readFileContents(entrypointPath))
        .hexadecimalRepresentation.uppercased())
    }

    try localFileSystem.writeFileContents(
      staticPath.appending(component: "so_sanitizer.wasm"),
      bytes: .init(StackOverflowSanitizer.supportObjectFile)
    )
    print("file written to \(staticPath.appending(component: "so_sanitizer.wasm"))")

    let archiveSources = try localFileSystem.traverseRecursively(staticPath)
      // `traverseRecursively` also returns the `staticPath` directory itself, dropping it here
      .dropFirst()
      .map(\.pathString)

    try await Process.run(["zip", "-j", "static.zip"] + archiveSources, terminal)

    let archiveHash = try SHA256().hash(
      localFileSystem.readFileContents(AbsolutePath(
        localFileSystem.currentWorkingDirectory!,
        RelativePath("static.zip")
      ))
    ).hexadecimalRepresentation.uppercased()

    let hashesFileContent = """
    import TSCBasic

    \(hashes.map {
      """
      public let \($0)EntrypointSHA256 = ByteString([
      \(arrayString(from: $1))
      ])


      """
    }.joined())public let staticArchiveHash = ByteString([
    \(arrayString(from: archiveHash)),
    ])

    """

    try localFileSystem.writeFileContents(
      AbsolutePath(
        cwd,
        RelativePath("Sources").appending(components: "CartonKit", "Server", "StaticArchive.swift")
      ),
      bytes: ByteString(encodingAsUTF8: hashesFileContent)
    )
  }
}
