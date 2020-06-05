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

import Crypto
import Foundation

// swiftlint:disable:next line_length
private let devPolyfillHash = "8564fd80b4565ed2eea9478ec6999ac03572fd2cb6a3a1d16382d094590fa096ac2deb2db8cd3d9a75fcdf51699e9698e5059728408e18b7c5817189893311b9"

private let archiveURL = URL(
  string: "https://github.com/swiftwasm/carton/releases/download/0.0.1/static.zip"
)

func checkDevDependencies() throws {
  let fm = FileManager.default
  let devPolyfill = fm.homeDirectoryForCurrentUser.appending(".carton", "static", "dev.js")
  let data = try Data(contentsOf: devPolyfill)

  let hash = SHA512.hash(data: data)
}
