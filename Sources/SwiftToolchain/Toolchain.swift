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
import TSCUtility
import WasmTransformer

public let compatibleJSKitVersion = Version(0, 11, 1)

enum ToolchainError: Error, CustomStringConvertible {
  case directoryDoesNotExist(AbsolutePath)
  case invalidResponseCode(UInt)
  case invalidInstallationArchive(AbsolutePath)
  case noExecutableProduct
  case failedToBuild(product: String)
  case failedToBuildTestBundle
  case missingPackageManifest
  case invalidVersion(version: String)
  case invalidResponse(url: String, status: UInt)
  case unsupportedOperatingSystem
  case noInstallationDirectory(path: String)

  var description: String {
    switch self {
    case let .directoryDoesNotExist(path):
      return "Directory at path \(path.pathString) does not exist and could not be created"
    case let .invalidResponseCode(code):
      return """
      While attempting to download an archive, the server returned an invalid response code \(code)
      """
    case let .invalidInstallationArchive(path):
      return "Invalid toolchain/SDK archive was installed at path \(path)"
    case .noExecutableProduct:
      return "No executable product to build could be inferred"
    case let .failedToBuild(product):
      return "Failed to build executable product \(product)"
    case .failedToBuildTestBundle:
      return "Failed to build the test bundle"
    case .missingPackageManifest:
      return """
      The `Package.swift` manifest file could not be found. Please navigate to a directory that \
      contains `Package.swift` and restart.
      """
    case let .invalidVersion(version):
      return "Invalid version \(version)"
    case let .invalidResponse(url: url, status: status):
      return "Response from \(url) had invalid status \(status) or didn't contain body"
    case .unsupportedOperatingSystem:
      return "This version of the operating system is not supported"
    case let .noInstallationDirectory(path):
      return """
      Failed to infer toolchain installation directory. Please make sure that \(path) exists.
      """
    }
  }
}

extension PackageDependencyDescription.Requirement {
  var isJavaScriptKitCompatible: Bool {
    switch self {
    case let .exact(version):
      return version == compatibleJSKitVersion
    case let .range(range):
      return range.upperBound >= compatibleJSKitVersion
    default:
      return false
    }
  }

  var versionDescription: String {
    switch self {
    case let .exact(version):
      return version.description
    case let .range(range):
      return range.lowerBound.description
    default:
      return "(Unknown)"
    }
  }
}

public final class Toolchain {
  private let fileSystem: FileSystem
  private let terminal: InteractiveWriter

  private let version: String
  private let swiftPath: AbsolutePath
  public let manifest: Result<Manifest, Error>

  public init(
    for versionSpec: String? = nil,
    _ fileSystem: FileSystem,
    _ terminal: InteractiveWriter
  ) throws {
    let toolchainSystem = ToolchainSystem(fileSystem: fileSystem)
    let (swiftPath, version) = try toolchainSystem.inferSwiftPath(from: versionSpec, terminal)
    self.swiftPath = swiftPath
    self.version = version
    self.fileSystem = fileSystem
    self.terminal = terminal
    manifest = Result { try Manifest.from(swiftPath: swiftPath, terminal: terminal) }
  }

  private func inferBinPath(isRelease: Bool) throws -> AbsolutePath {
    guard
      let output = try processStringOutput([
        swiftPath.pathString, "build", "-c", isRelease ? "release" : "debug",
        "--triple", "wasm32-unknown-wasi", "--show-bin-path",
      ])?.components(separatedBy: CharacterSet.newlines),
      let binPath = output.first
    else { fatalError("failed to decode UTF8 output of the `swift build` invocation") }

    return AbsolutePath(binPath)
  }

  private func inferDevProduct(hint: String?) throws -> ProductDescription? {
    let manifest = try self.manifest.get()

    var candidateProducts = manifest.products
      .filter { $0.type == .executable }

    if let productName = hint {
      candidateProducts = candidateProducts.filter { $0.name == productName }

      guard candidateProducts.count == 1 else {
        terminal.write("""
        Failed to disambiguate the executable product, \
        make sure `\(productName)` product is present in Package.swift
        """, inColor: .red)
        return nil
      }

      terminal.logLookup("- development product: ", productName)
      return candidateProducts[0]
    } else if candidateProducts.count == 1 {
      return candidateProducts[0]
    } else {
      terminal.write("Failed to disambiguate the development product\n", inColor: .red)

      if candidateProducts.count > 1 {
        terminal.write("Pass one of \(candidateProducts) to the --product option\n", inColor: .red)
      } else {
        terminal.write(
          "Make sure there's at least one executable product in your Package.swift\n",
          inColor: .red
        )
      }

      return nil
    }
  }

  private func inferManifestDirectory() throws -> AbsolutePath {
    guard (try? manifest.get()) != nil, var cwd = fileSystem.currentWorkingDirectory else {
      throw ToolchainError.missingPackageManifest
    }

    repeat {
      guard !fileSystem.isFile(cwd.appending(component: "Package.swift")) else {
        return cwd
      }

      // `parentDirectory` just returns `self` if it's `root`
      cwd = cwd.parentDirectory
    } while !cwd.isRoot

    throw ToolchainError.missingPackageManifest
  }

  public func inferSourcesPaths() throws -> [AbsolutePath] {
    let manifest = try self.manifest.get()

    let targetPaths = manifest.targets.compactMap { target -> String? in

      guard let path = target.path else {
        switch target.type {
        case .regular:
          return RelativePath("Sources").appending(component: target.name).pathString
        case .test, .system, .executable, .binary, .plugin:
          return nil
        }
      }
      return path
    }

    let manifestDirectory = try inferManifestDirectory()

    return try targetPaths.compactMap {
      try manifestDirectory.appending(RelativePath(validating: $0))
    }
  }

  public func buildCurrentProject(
    product: String?,
    flavor: BuildFlavor
  ) throws -> BuildDescription {
    guard let product = try inferDevProduct(hint: product)
    else { throw ToolchainError.noExecutableProduct }

    let manifest = try self.manifest.get()
    let jsKit = manifest.dependencies.first {
      $0.nameForTargetDependencyResolutionOnly == "JavaScriptKit"
    }

    switch jsKit {
    case let .scm(jsKit) where !jsKit.requirement.isJavaScriptKitCompatible:
      let versionDescription = jsKit.requirement.versionDescription

      terminal.write(
        """

        JavaScriptKit \(versionDescription), which is present in your dependency tree is not \
        known to be compatible with carton \(cartonVersion). Please specify a JavaScriptKit \
        dependency on version \(compatibleJSKitVersion) in your `Package.swift`.\n

        """,
        inColor: .red
      )

    case .local:
      terminal.write(
        """

        The version of JavaScriptKit found in your dependency tree is not known to be compatible \
        with carton \(cartonVersion). Please specify a JavaScriptKit dependency on version \
        \(compatibleJSKitVersion) in your `Package.swift`.\n

        """,
        inColor: .red
      )

    case nil, .scm:
      break
    }

    let binPath = try inferBinPath(isRelease: flavor.isRelease)
    let mainWasmPath = binPath.appending(component: "\(product.name).wasm")
    terminal.logLookup("- development binary to serve: ", mainWasmPath.pathString)

    terminal.write("\nBuilding the project before spinning up a server...\n", inColor: .yellow)

    var builderArguments = [
      swiftPath.pathString, "build", "-c", flavor.isRelease ? "release" : "debug",
      "--product", product.name, "--triple", "wasm32-unknown-wasi",
    ]

    // Versions later than 5.3.x have test discovery enabled by default and the explicit flag
    // deprecated.
    if ["wasm-5.3.0-RELEASE", "wasm-5.3.1-RELEASE"].contains(version) {
      builderArguments.append("--enable-test-discovery")
    }

    try Builder(
      arguments: builderArguments,
      mainWasmPath: mainWasmPath,
      flavor,
      fileSystem,
      terminal
    )
    .runAndWaitUntilFinished()

    guard fileSystem.exists(mainWasmPath) else {
      terminal.write(
        "Failed to build the main executable binary, fix the build errors and restart\n",
        inColor: .red
      )
      throw ToolchainError.failedToBuild(product: product.name)
    }

    return .init(arguments: builderArguments, mainWasmPath: mainWasmPath, product: product)
  }

  /// Returns an absolute path to the resulting test bundle
  public func buildTestBundle(
    flavor: BuildFlavor
  ) throws -> AbsolutePath {
    let manifest = try self.manifest.get()
    let binPath = try inferBinPath(isRelease: flavor.isRelease)
    let testProductName = "\(manifest.name)PackageTests"
    let testBundlePath = binPath.appending(component: "\(testProductName).wasm")
    terminal.logLookup("- test bundle to run: ", testBundlePath.pathString)

    terminal.write(
      "\nBuilding the test bundle before running the test suite...\n",
      inColor: .yellow
    )

    var builderArguments = [
      swiftPath.pathString, "build", "-c", flavor.isRelease ? "release" : "debug",
      "--product", testProductName, "--triple", "wasm32-unknown-wasi",
      "-Xswiftc", "-color-diagnostics", 
      // workaround for 5.5 linking issues, see https://github.com/swiftwasm/swift/issues/3891
      "-Xlinker", "-licuuc", "-Xlinker", "-licui18n"
    ]

    // Versions later than 5.3.x have test discovery enabled by default and the explicit flag
    // deprecated.
    if ["wasm-5.3.0-RELEASE", "wasm-5.3.1-RELEASE"].contains(version) {
      builderArguments.append("--enable-test-discovery")
    }

    try Builder(
      arguments: builderArguments,
      mainWasmPath: testBundlePath,
      flavor,
      fileSystem,
      terminal
    )
    .runAndWaitUntilFinished()

    guard fileSystem.exists(testBundlePath) else {
      terminal.write(
        "Failed to build the test bundle, fix the build errors and restart\n",
        inColor: .red
      )
      throw ToolchainError.failedToBuildTestBundle
    }

    return testBundlePath
  }

  public func packageInit(name: String, type: PackageType, inPlace: Bool) throws {
    var initArgs = [
      swiftPath.pathString, "package", "init",
      "--type", type.rawValue,
    ]
    if !inPlace {
      initArgs.append(contentsOf: ["--name", name])
    }
    try ProcessRunner(initArgs, terminal)
      .waitUntilFinished()
  }

  public func runPackage(_ arguments: [String]) throws {
    let args = [swiftPath.pathString, "package"] + arguments
    try ProcessRunner(args, terminal)
      .waitUntilFinished()
  }
}
