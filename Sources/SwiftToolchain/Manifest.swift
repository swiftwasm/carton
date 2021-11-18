// Copyright 2021 Carton contributors
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
    let decoder = JSONDecoder()
    let unencodedValues = DumpedManifest.Unencoded(
      path: swiftPath,
      url: swiftPath.asURL.absoluteString,
      version: nil
    )
    decoder.userInfo[DumpedManifest.unencodedKey] = unencodedValues
    let dumpedManifest = try decoder.decode(DumpedManifest.self, from: output)
    return dumpedManifest.manifest
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

// MARK: Custom Decodable Wrappers

/// A wrapper around `Manifest` needed for decoding from `dump-package` output,
/// since when encoding several (required for initialization) keys are skipped.
/// When decoding this wrapper, callers must provide an `unencodedKey` in the
/// decoder's `userInfo`.
struct DumpedManifest: Decodable {
  var manifest: Manifest

  static let unencodedKey = CodingUserInfoKey(rawValue: "unencoded")!

  /// The skipped keys during `dump-package` encoding
  struct Unencoded {
    let path: AbsolutePath
    let url: String
    let version: Version?
  }

  private enum CodingKeys: CodingKey {
    case name, toolsVersion,
      pkgConfig, providers, cLanguageStandard, cxxLanguageStandard, swiftLanguageVersions,
      dependencies, products, targets, platforms, packageKind, revision,
      defaultLocalization
  }

  init(from decoder: Decoder) throws {
    guard let unencoded = decoder.userInfo[DumpedManifest.unencodedKey] as? Unencoded else {
      let context = DecodingError.Context(
        codingPath: [],
        debugDescription: "Unencoded values are missing from Decoder's userInfo"
      )
      throw DecodingError.dataCorrupted(context)
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    let name = try container.decode(String.self, forKey: .name)
    let toolsVersion = try container.decode(ToolsVersion.self, forKey: .toolsVersion)
    let pkgConfig = try container.decode(String?.self, forKey: .pkgConfig)
    let providers = try container.decode(
      [SystemPackageProviderDescription]?.self,
      forKey: .providers
    )
    let cLanguageStandard = try container.decode(String?.self, forKey: .cLanguageStandard)
    let cxxLanguageStandard = try container.decode(String?.self, forKey: .cxxLanguageStandard)
    let swiftLanguageVersions = try container.decode(
      [SwiftLanguageVersion]?.self,
      forKey: .swiftLanguageVersions
    )
    let dependencies = try container.decode(
      [PackageDependencyDescription].self,
      forKey: .dependencies
    )
    let products = try container.decode([ProductDescription].self, forKey: .products)
    let targets = try container.decode([TargetDescription].self, forKey: .targets)
    let platforms = try container.decode([PlatformDescription].self, forKey: .platforms)
    let packageKind = try container.decode(PackageReference.Kind.self, forKey: .packageKind)
    manifest = Manifest(
      name: name,
      path: unencoded.path,
      packageKind: packageKind,
      packageLocation: unencoded.url,
      defaultLocalization: nil, // not encoded in JSON
      platforms: platforms,
      version: unencoded.version,
      revision: nil, // not encoded in JSON
      toolsVersion: toolsVersion,
      pkgConfig: pkgConfig,
      providers: providers,
      cLanguageStandard: cLanguageStandard,
      cxxLanguageStandard: cxxLanguageStandard,
      swiftLanguageVersions: swiftLanguageVersions,
      dependencies: dependencies,
      products: products,
      targets: targets
    )
  }
}
