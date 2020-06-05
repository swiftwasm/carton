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
import ZIPFoundation

private let devPolyfillHash: [UInt8] = [
  0x85, 0x64, 0xFD, 0x80, 0xB4, 0x56, 0x5E, 0xD2, 0xEE, 0xA9, 0x47, 0x8E, 0xC6, 0x99, 0x9A, 0xC0,
  0x35, 0x72, 0xFD, 0x2C, 0xB6, 0xA3, 0xA1, 0xD1, 0x63, 0x82, 0xD0, 0x94, 0x59, 0x0F, 0xA0, 0x96,
  0xAC, 0x2D, 0xEB, 0x2D, 0xB8, 0xCD, 0x3D, 0x9A, 0x75, 0xFC, 0xDF, 0x51, 0x69, 0x9E, 0x96, 0x98,
  0xE5, 0x05, 0x97, 0x28, 0x40, 0x8E, 0x18, 0xB7, 0xC5, 0x81, 0x71, 0x89, 0x89, 0x33, 0x11, 0xB9,
]
private let archiveHash: [UInt8] = [
  0x1A, 0x58, 0xC7, 0xC4, 0x2C, 0x4D, 0x30, 0xDF, 0x73, 0x5D, 0x89, 0xCE, 0xAF, 0xA5, 0x4B, 0x01,
  0x40, 0x30, 0x45, 0xD3, 0xDD, 0x5C, 0x9D, 0x55, 0xBC, 0x9D, 0xE7, 0x83, 0xC6, 0x3A, 0x59, 0x57,
  0x7D, 0xF2, 0x2A, 0x2F, 0x9A, 0x6F, 0xF9, 0x88, 0xB8, 0x7F, 0x1F, 0x73, 0x72, 0x74, 0x45, 0x43,
  0xC6, 0xAF, 0x90, 0xBA, 0x22, 0x3E, 0xAC, 0xC6, 0x49, 0xE7, 0xA8, 0x10, 0x60, 0xBF, 0xD4, 0xF8,
]

private let archiveURL = URL(
  string: "https://github.com/swiftwasm/carton/releases/download/0.0.1/static.zip"
)!

private let verifyHash = Equality<[UInt8], URL> {
  """
  Expected SHA512 of \($2), which is
  \($0)
  to equal
  \(1)
  """
}

func checkDevDependencies() throws {
  let fm = FileManager.default
  let cartonDir = fm.homeDirectoryForCurrentUser.appending(".carton")
  let devPolyfill = cartonDir.appending("static", "dev.js")

  // If dev.js hash fails, download the `static.zip` archive and unpack it/
  if try !fm.fileExists(
    atPath: devPolyfill.path
  ) || Data(contentsOf: devPolyfill).sha512 != devPolyfillHash {
    print("Downloading the polyfill archive from \(archiveURL)...")
    let downloadedArchive = try Data(contentsOf: archiveURL)
    let downloadedHash = downloadedArchive.sha512
    try verifyHash(downloadedHash, archiveHash, context: archiveURL)

    let archiveFile = cartonDir.appending("static.zip")
    try fm.createDirectory(at: cartonDir, withIntermediateDirectories: true)
    try downloadedArchive.write(to: archiveFile)
    try fm.unzipItem(at: archiveFile, to: cartonDir)
  }

  let unpackedPolyfillHash = try Data(contentsOf: devPolyfill).sha512
  // Nothing we can do after the hash doesn't match after unpacking
  try verifyHash(unpackedPolyfillHash, devPolyfillHash, context: devPolyfill)
}
