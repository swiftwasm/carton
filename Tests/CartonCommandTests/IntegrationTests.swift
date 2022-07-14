// Copyright 2022 Carton contributors
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

@testable import CartonCLI
import TSCBasic
import XCTest

final class IntegrationTests: XCTestCase {
  func testTokamakBundle() throws {
    try withTemporaryDirectory { tmpDirPath in
      try ProcessEnv.chdir(tmpDirPath)
      try Process.checkNonZeroExit(arguments: [cartonPath, "init", "--template", "tokamak"])
      try Process.checkNonZeroExit(arguments: [cartonPath, "bundle"])
    }
  }
}
