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
import TSCBasic
import TSCUtility

private let archiveHash = ByteString([
  0x57, 0x85, 0xBD, 0xD5, 0xF7, 0x68, 0x22, 0xB3, 0x13, 0x3D, 0xA3, 0x8B, 0xB7, 0xB4, 0x2A, 0x9F,
  0xF4, 0x93, 0x47, 0x4B, 0x44, 0x64, 0x7E, 0x93, 0xD5, 0x8B, 0x08, 0xE1, 0x26, 0x03, 0x68, 0xB4,
])

private let archiveURL = "https://github.com/swiftwasm/carton/releases/download/0.0.2/static.zip"

private let verifyHash = Equality<ByteString, String> {
  """
  Expected SHA256 of \($2), which is
  \($0.hexadecimalRepresentation)
  to equal
  \($1.hexadecimalRepresentation)
  """
}

enum DependencyError: Error {
  case downloadFailed(url: String)
}

struct Dependency {
  let fileName: String
  let sha256: ByteString

  func check(on fileSystem: FileSystem, _ terminal: TerminalController) throws {
    let cartonDir = fileSystem.homeDirectory.appending(component: ".carton")
    let staticDir = cartonDir.appending(component: "static")
    let devPolyfill = cartonDir.appending(components: "static", fileName)

    // If dev.js hash fails, download the `static.zip` archive and unpack it/
    if try !fileSystem.exists(devPolyfill) || SHA256().hash(
      fileSystem.readFileContents(devPolyfill)
    ) != sha256 {
      terminal.logLookup("Directory doesn't exist or contains outdated polyfills: ", staticDir)
      try fileSystem.removeFileTree(cartonDir)

      let client = HTTPClient(eventLoopGroupProvider: .createNew)
      let response: HTTPClient.Response = try await {
        client.get(url: archiveURL).whenComplete($0)
      }
      try client.syncShutdown()

      guard
        var body = response.body,
        let bytes = body.readBytes(length: body.readableBytes)
      else { throw DependencyError.downloadFailed(url: archiveURL) }

      let downloadedArchive = ByteString(bytes)

      let downloadedHash = SHA256().hash(downloadedArchive)
      try verifyHash(downloadedHash, archiveHash, context: archiveURL)

      let archiveFile = cartonDir.appending(component: "static.zip")
      try fileSystem.createDirectory(cartonDir, recursive: true)
      try fileSystem.writeFileContents(archiveFile, bytes: downloadedArchive)
      terminal.logLookup("Unpacking the archive: ", archiveFile)

      try await {
        ZipArchiver().extract(from: archiveFile, to: cartonDir, completion: $0)
      }
    }

    let unpackedPolyfillHash = try SHA256().hash(fileSystem.readFileContents(devPolyfill))
    // Nothing we can do after the hash doesn't match after unpacking
    try verifyHash(unpackedPolyfillHash, sha256, context: devPolyfill.pathString)
    terminal.logLookup("Polyfill integrity verified: ", devPolyfill)
  }
}
