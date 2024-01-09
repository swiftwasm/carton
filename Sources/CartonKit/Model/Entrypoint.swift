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

private struct StringError: Equatable, Codable, CustomStringConvertible, Error {
  let description: String
  init(_ description: String) {
    self.description = description
  }
}

extension StringError: CustomNSError {
  var errorUserInfo: [String: Any] {
    return [NSLocalizedDescriptionKey: self.description]
  }
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
  ) throws -> (cartonDir: AbsolutePath, staticDir: AbsolutePath, filePath: AbsolutePath) {
    let cartonDir = try fileSystem.homeDirectory.appending(component: ".carton")
    let staticDir = cartonDir.appending(component: "static")
    return (cartonDir, staticDir, staticDir.appending(component: fileName))
  }

  public func check(on fileSystem: FileSystem, _ terminal: InteractiveWriter) throws {
    let (cartonDir, staticDir, filePath) = try paths(on: fileSystem)

    // If hash check fails, download the `static.zip` archive and unpack it
    if try !fileSystem.exists(filePath, followSymlink: true)
      || SHA256().hash(
        fileSystem.readFileContents(filePath)
      ) != sha256
    {
      terminal.logLookup("Directory doesn't exist or contains outdated polyfills: ", staticDir)
      let archiveFile = cartonDir.appending(component: "static.zip")
      try fileSystem.removeFileTree(staticDir)
      try fileSystem.removeFileTree(archiveFile)

      let staticArchiveBytes = Data(base64Encoded: staticArchiveContents)!
      try fileSystem.createDirectory(cartonDir, recursive: true)
      try fileSystem.writeFileContents(archiveFile, bytes: ByteString(staticArchiveBytes))
      terminal.logLookup("Unpacking the archive: ", archiveFile)

      try fileSystem.createDirectory(staticDir, recursive: false)
      let result = try Process.popen(
        args: "unzip", archiveFile.pathString, "-d", staticDir.pathString)
      guard result.exitStatus == .terminated(code: 0) else {
        throw try StringError(result.utf8stderrOutput())
      }
    }
  }
}
