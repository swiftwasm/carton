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

import Basics
import CartonHelpers
import PackageModel
import PackageLoading
import TSCBasic
import Workspace

extension Manifest {
  static func from(path: AbsolutePath, binDir: AbsolutePath, fileSystem: FileSystem, terminal: InteractiveWriter) async throws -> Manifest {
    terminal.write("\nParsing package manifest: ", inColor: .yellow)
    let destination = try Destination.hostDestination(binDir)
    let toolchain = try UserToolchain(destination: destination)
    let loader = ManifestLoader(toolchain: toolchain)
    let observability = ObservabilitySystem { _, diagnostic in
      terminal.write("\n\(diagnostic)")
    }
    let workspace = try Workspace(fileSystem: fileSystem, forRootPackage: path, customManifestLoader: loader)
    let manifest = try await workspace.loadRootManifest(
      at: path,
      observabilityScope: observability.topScope
    )
    return manifest
  }

  public func resourcesPath(for target: TargetDescription) -> String {
    "\(displayName)_\(target.name).resources"
  }
}

extension Workspace {
  func loadRootManifest(
    at path: AbsolutePath,
    observabilityScope: ObservabilityScope
  ) async throws -> Manifest {
    try await withCheckedThrowingContinuation { continuation in
      loadRootManifest(at: path, observabilityScope: observabilityScope) { result in
        continuation.resume(with: result)
      }
    }
  }
}

public enum PackageType: String {
  case empty
  case library
  case executable
  case systemModule = "system-module"
  case manifest
}
