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

public let compatibleJSKitVersion = Version(0, 12, 0)

enum ToolchainError: Error, CustomStringConvertible {
  case directoryDoesNotExist(AbsolutePath)
  case invalidInstallationArchive(AbsolutePath)
  case noExecutableProduct
  case failedToBuild(product: String)
  case failedToBuildTestBundle
  case missingPackageManifest
  case invalidVersion(version: String)
  case invalidResponse(url: String, status: UInt)
  case unsupportedOperatingSystem
  case noInstallationDirectory(path: String)
  case noWorkingDirectory

  var description: String {
    switch self {
    case let .directoryDoesNotExist(path):
      return "Directory at path \(path.pathString) does not exist and could not be created"
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
    case .noWorkingDirectory:
      return "Working directory cannot be inferred from file system"
    }
  }
}

extension PackageDependency {
  var isJavaScriptKitCompatible: Bool {
    var exactVersion: Version?
    var versionRange: Range<Version>?
    switch self {
    case let .sourceControl(sourceControl):
      switch sourceControl.requirement {
      case let .exact(version): exactVersion = version
      case let .range(range): versionRange = range
      default: break
      }
    case let .registry(registry):
      switch registry.requirement {
      case let .exact(version): exactVersion = version
      case let .range(range): versionRange = range
      }
    default: break
    }
    if let exactVersion = exactVersion {
      return exactVersion == compatibleJSKitVersion
    }
    if let versionRange = versionRange {
      return versionRange.upperBound >= compatibleJSKitVersion
    }
    return false
  }

  var requirementDescription: String {
    switch self {
    case let .sourceControl(sourceControl):
      return sourceControl.requirement.description
    case let .registry(registry):
      return registry.requirement.description
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
  ) async throws {
    let toolchainSystem = ToolchainSystem(fileSystem: fileSystem)
    let (swiftPath, version) = try await toolchainSystem.inferSwiftPath(from: versionSpec, terminal)
    self.swiftPath = swiftPath
    self.version = version
    self.fileSystem = fileSystem
    self.terminal = terminal
    if let workingDirectory = fileSystem.currentWorkingDirectory {
      let swiftc = swiftPath.parentDirectory.appending(component: "swiftc")
      manifest = await Result { try await Manifest.from(path: workingDirectory, swiftc: swiftc, fileSystem: fileSystem, terminal: terminal)
      }
    } else {
      manifest = .failure(ToolchainError.noWorkingDirectory)
    }
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
        case .regular, .executable:
          return RelativePath("Sources").appending(component: target.name).pathString
        case .test, .system, .binary, .plugin:
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

  private func emitJSKitWarningIfNeeded() throws {
    let manifest = try self.manifest.get()
    guard let jsKit = manifest.dependencies.first(where: {
      $0.nameForTargetDependencyResolutionOnly == "JavaScriptKit"
    }) else {
      return
    }

    switch jsKit {
    case .fileSystem:
      terminal.write(
        """

        The local version of JavaScriptKit found in your dependency tree is not known to be compatible \
        with carton \(cartonVersion). Please specify a JavaScriptKit dependency of version \
        \(compatibleJSKitVersion) in your `Package.swift`.\n

        """,
        inColor: .red
      )

    default:
      guard !jsKit.isJavaScriptKitCompatible else { return }
      terminal.write(
        """

        JavaScriptKit requirement \(jsKit
          .requirementDescription), which is present in your dependency tree is not \
        known to be compatible with carton \(cartonVersion). Please specify a JavaScriptKit \
        dependency of version \(compatibleJSKitVersion) in your `Package.swift`.\n

        """,
        inColor: .red
      )
    }
  }

  public func buildCurrentProject(
    product: String?,
    flavor: BuildFlavor
  ) async throws -> BuildDescription {
    guard let product = try inferDevProduct(hint: product)
    else { throw ToolchainError.noExecutableProduct }

    try emitJSKitWarningIfNeeded()

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

    // SwiftWasm 5.5 requires explicit linking arguments in certain configurations,
    // see https://github.com/swiftwasm/swift/issues/3891
    if version.starts(with: "wasm-5.5") {
      builderArguments.append(contentsOf: ["-Xlinker", "-licuuc", "-Xlinker", "-licui18n"])
    }

    builderArguments.append(contentsOf: flavor.swiftCompilerFlags.flatMap {
      ["-Xswiftc", $0]
    })

    try await Builder(
      arguments: builderArguments,
      mainWasmPath: mainWasmPath,
      flavor,
      fileSystem,
      terminal
    ).run()

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
  ) async throws -> AbsolutePath {
    let manifest = try self.manifest.get()
    let binPath = try inferBinPath(isRelease: flavor.isRelease)
    let testProductName = "\(manifest.displayName)PackageTests"
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
    ]

    // Versions later than 5.3.x have test discovery enabled by default and the explicit flag
    // deprecated.
    if ["wasm-5.3.0-RELEASE", "wasm-5.3.1-RELEASE"].contains(version) {
      builderArguments.append("--enable-test-discovery")
    }

    // SwiftWasm 5.5 requires explicit linking arguments in certain configurations,
    // see https://github.com/swiftwasm/swift/issues/3891
    if version.starts(with: "wasm-5.5") {
      builderArguments.append(contentsOf: ["-Xlinker", "-licuuc", "-Xlinker", "-licui18n"])
    }

    builderArguments.append(contentsOf: flavor.swiftCompilerFlags.flatMap {
      ["-Xswiftc", $0]
    })

    try await Builder(
      arguments: builderArguments,
      mainWasmPath: testBundlePath,
      flavor,
      fileSystem,
      terminal
    ).run()

    guard fileSystem.exists(testBundlePath) else {
      terminal.write(
        "Failed to build the test bundle, fix the build errors and restart\n",
        inColor: .red
      )
      throw ToolchainError.failedToBuildTestBundle
    }

    return testBundlePath
  }

  public func runPackageInit(name: String, type: PackageType, inPlace: Bool) async throws {
    var initArgs = [
      swiftPath.pathString, "package", "init",
      "--type", type.rawValue,
    ]
    if !inPlace {
      initArgs.append(contentsOf: ["--name", name])
    }
    try await TSCBasic.Process.run(initArgs, terminal)
  }

  public func runPackage(_ arguments: [String]) async throws {
    let args = [swiftPath.pathString, "package"] + arguments
    try await TSCBasic.Process.run(args, terminal)
  }
}

extension Result where Failure == Error {
  init(catching body: () async throws -> Success) async {
    do {
      let value = try await body()
      self = .success(value)
    } catch {
      self = .failure(error)
    }
  }
}
