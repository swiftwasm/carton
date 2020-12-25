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
import CartonHelpers
import Foundation
import TSCBasic
import TSCUtility

/** The `static.zip` archive is always uploaded to release assets of a previous release
 instead of the forthcoming release, because the corresponding new release tag doesn't exist yet.
 */
private let staticArchiveURL =
  "https://github.com/swiftwasm/carton/releases/download/0.8.2/static.zip"

private let verifyHash = Equality<ByteString, String> {
  """
  Expected SHA256 of \($2), which is
  \($0.hexadecimalRepresentation)
  to equal
  \($1.hexadecimalRepresentation)
  """
}

public enum EntrypointError: Error {
  case downloadFailed(url: String)
}

public struct Entrypoint {
  let fileName: String
  let sha256: ByteString

  public init(fileName: String, sha256: ByteString) {
    self.fileName = fileName
    self.sha256 = sha256
  }

  public func paths(
    on fileSystem: FileSystem
    // swiftlint:disable:next large_tuple
  ) -> (cartonDir: AbsolutePath, staticDir: AbsolutePath, filePath: AbsolutePath) {
    let cartonDir = fileSystem.homeDirectory.appending(component: ".carton")
    let staticDir = cartonDir.appending(component: "static")
    return (cartonDir, staticDir, staticDir.appending(component: fileName))
  }

  public func check(on fileSystem: FileSystem, _ terminal: InteractiveWriter) throws {
    let (cartonDir, staticDir, filePath) = paths(on: fileSystem)

    // If hash check fails, download the `static.zip` archive and unpack it
    if try !fileSystem.exists(filePath) || SHA256().hash(
      fileSystem.readFileContents(filePath)
    ) != sha256 {
      terminal.logLookup("Directory doesn't exist or contains outdated polyfills: ", staticDir)
      let archiveFile = cartonDir.appending(component: "static.zip")
      try fileSystem.removeFileTree(staticDir)
      try fileSystem.removeFileTree(archiveFile)

      let client = HTTPClient(eventLoopGroupProvider: .createNew)
      let request = try HTTPClient.Request.get(url: staticArchiveURL)
      let response: HTTPClient.Response = try tsc_await {
        client.execute(request: request).whenComplete($0)
      }
      try client.syncShutdown()

      guard
        var body = response.body,
        let bytes = body.readBytes(length: body.readableBytes)
      else { throw EntrypointError.downloadFailed(url: staticArchiveURL) }

      terminal.logLookup("Polyfills archive successfully downloaded from ", staticArchiveURL)

      let downloadedArchive = ByteString(bytes)

      let downloadedHash = SHA256().hash(downloadedArchive)
      try verifyHash(downloadedHash, staticArchiveHash, context: staticArchiveURL)

      try fileSystem.createDirectory(cartonDir, recursive: true)
      try fileSystem.writeFileContents(archiveFile, bytes: downloadedArchive)
      terminal.logLookup("Unpacking the archive: ", archiveFile)

      try fileSystem.createDirectory(staticDir)
      try tsc_await {
        ZipArchiver().extract(from: archiveFile, to: staticDir, completion: $0)
      }
    }

    let unpackedEntrypointHash = try SHA256().hash(fileSystem.readFileContents(filePath))
    // Nothing we can do after the hash doesn't match after unpacking
    try verifyHash(unpackedEntrypointHash, sha256, context: filePath.pathString)
    terminal.logLookup("Entrypoint integrity verified: ", filePath)
  }
}
