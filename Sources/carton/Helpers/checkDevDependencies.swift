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
import TSCUtility

private let devPolyfillHash = ByteString([
  0x93, 0xDF, 0xFB, 0x13, 0xFE, 0x5A, 0x44, 0x4F, 0xE2, 0x0C, 0xF1, 0x13, 0x89, 0x25, 0x99, 0xE0,
  0x44, 0x00, 0x61, 0x99, 0x29, 0xFC, 0xAC, 0x0C, 0x32, 0x3C, 0xAD, 0xAA, 0x71, 0x45, 0xFB, 0x45,
])
private let archiveHash = ByteString([
  0xCE, 0x95, 0x77, 0x77, 0xFE, 0xED, 0x60, 0x7E, 0xE2, 0x14, 0x6F, 0x36, 0x07, 0xE0, 0x86, 0x79,
  0x0C, 0x6F, 0x38, 0x43, 0x2C, 0x3B, 0xA2, 0x5F, 0x6A, 0x8C, 0x83, 0x8D, 0xEE, 0x55, 0x6B, 0xBE,
])

private let archiveURL = URL(
  string: "https://github.com/swiftwasm/carton/releases/download/0.0.2/static.zip"
)!

private let verifyHash = Equality<ByteString, Foundation.URL> {
  """
  Expected SHA512 of \($2), which is
  \($0)
  to equal
  \(1)
  """
}

func checkDevDependencies(on fileSystem: FileSystem, _ terminal: TerminalController) throws {
  let cartonDir = fileSystem.homeDirectory.appending(component: ".carton")
  let staticDir = cartonDir.appending(component: "static")
  let devPolyfill = cartonDir.appending(components: "static", "dev.js")

  // If dev.js hash fails, download the `static.zip` archive and unpack it/
  if try !fileSystem.exists(devPolyfill) || SHA256().hash(
    fileSystem.readFileContents(devPolyfill)
  ) != devPolyfillHash {
    terminal.logLookup("Directory doesn't exist or contains outdated polyfills: ", staticDir)
    try fileSystem.removeFileTree(cartonDir)

    terminal.logLookup("Downloading the polyfill archive: ", archiveURL)
    let downloadedArchive = try ByteString(Data(contentsOf: archiveURL))
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
  try verifyHash(unpackedPolyfillHash, devPolyfillHash, context: devPolyfill.asURL)
  terminal.logLookup("Polyfill integrity verified: ", devPolyfill)
}
