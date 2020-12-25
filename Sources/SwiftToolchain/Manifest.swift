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
import PackageModel
import TSCBasic

extension Manifest {
  static func from(swiftPath: AbsolutePath, terminal: InteractiveWriter) throws -> Manifest {
    terminal.write("\nParsing package manifest: ", inColor: .yellow)
    terminal.write("\(swiftPath) package dump-package\n")
    let output = try Data(processDataOutput([swiftPath.pathString, "package", "dump-package"]))
    return try JSONDecoder().decode(Manifest.self, from: output)
  }

  public func resourcesPath(for target: TargetDescription) -> String {
    "\(name)_\(target.name).resources"
  }
}

public enum PackageType: String {
  case empty
  case library
  case executable
  case systemModule = "system-module"
  case manifest
}
