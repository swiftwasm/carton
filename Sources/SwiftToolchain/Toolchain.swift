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
import TSCBasic
import TSCUtility

public let compatibleJSKitVersion = Version(0, 8, 0)

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

extension Package.Dependency.Requirement {
  var isJavaScriptKitCompatible: Bool {
    if let upperBound = range?.first?.upperBound, let version = Version(string: upperBound) {
      return version >= compatibleJSKitVersion
    }
    return exact?.compactMap { Version(string: $0) } == [compatibleJSKitVersion]
  }

  var version: String {
    revision?.first ?? range?.first?.lowerBound ?? ""
  }
}

public final class Toolchain {
  private let fileSystem: FileSystem
  private let terminal: InteractiveWriter

  private let version: String
  private let swiftPath: AbsolutePath
  public let package: Result<Package, Error>

  public init(
    for versionSpec: String? = nil,
    _ fileSystem: FileSystem,
    _ terminal: InteractiveWriter
  ) throws {
    let (swiftPath, version) = try fileSystem.inferSwiftPath(from: versionSpec, terminal)
    self.swiftPath = swiftPath
    self.version = version
    self.fileSystem = fileSystem
    self.terminal = terminal
    package = Result { try Package(with: swiftPath, terminal) }
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

  private func inferDevProduct(hint: String?) throws -> String? {
    let package = try self.package.get()

    var candidateProducts = package.products
      .filter { $0.type.library == nil }
      .map(\.name)

    if let product = hint {
      candidateProducts = candidateProducts.filter { $0 == product }

      guard candidateProducts.count == 1 else {
        terminal.write("""
        Failed to disambiguate the executable product, \
        make sure `\(product)` product is present in Package.swift
        """, inColor: .red)
        return nil
      }

      terminal.logLookup("- development product: ", product)
      return product
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
    guard (try? package.get()) != nil, var cwd = fileSystem.currentWorkingDirectory else {
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
    let package = try self.package.get()

    let targetPaths = package.targets.compactMap { target -> String? in
      guard let path = target.path else {
        switch target.type {
        case .regular:
          return "Sources/\(target.name)"
        case .test:
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
    isRelease: Bool
  ) throws -> (builderArguments: [String], mainWasmPath: AbsolutePath) {
    guard let product = try inferDevProduct(hint: product)
    else { throw ToolchainError.noExecutableProduct }

    let package = try self.package.get()
    if let jsKit = package.dependencies?.first(where: { $0.name == "JavaScriptKit" }),
      !jsKit.requirement.isJavaScriptKitCompatible
    {
      let version = jsKit.requirement.version

      terminal.write(
        """

        This version of JavaScriptKit \(version) is not known to be compatible with \
        carton \(cartonVersion). Please specify a JavaScriptKit dependency on version \
        \(compatibleJSKitVersion) in your `Package.swift`.\n

        """,
        inColor: .red
      )
    }

    let binPath = try inferBinPath(isRelease: isRelease)
    let mainWasmPath = binPath.appending(component: "\(product).wasm")
    terminal.logLookup("- development binary to serve: ", mainWasmPath.pathString)

    terminal.write("\nBuilding the project before spinning up a server...\n", inColor: .yellow)

    let builderArguments = [
      swiftPath.pathString, "build", "-c", isRelease ? "release" : "debug", "--product", product,
      "--enable-test-discovery", "--triple", "wasm32-unknown-wasi",
    ]

    try Builder(arguments: builderArguments, mainWasmPath: mainWasmPath, fileSystem, terminal)
      .runAndWaitUntilFinished()

    guard fileSystem.exists(mainWasmPath) else {
      terminal.write(
        "Failed to build the main executable binary, fix the build errors and restart\n",
        inColor: .red
      )
      throw ToolchainError.failedToBuild(product: product)
    }

    return (builderArguments, mainWasmPath)
  }

  /// Returns an absolute path to the resulting test bundle
  public func buildTestBundle(isRelease: Bool) throws -> AbsolutePath {
    let package = try self.package.get()
    let binPath = try inferBinPath(isRelease: isRelease)
    let testBundlePath = binPath.appending(component: "\(package.name)PackageTests.xctest")
    terminal.logLookup("- test bundle to run: ", testBundlePath.pathString)

    terminal.write(
      "\nBuilding the test bundle before running the test suite...\n",
      inColor: .yellow
    )

    let builderArguments = [
      swiftPath.pathString, "build", "-c", isRelease ? "release" : "debug",
      "--product", "\(package.name)PackageTests", "--enable-test-discovery",
      "--triple", "wasm32-unknown-wasi", "-Xswiftc", "-color-diagnostics",
    ]

    try Builder(
      arguments: builderArguments,
      mainWasmPath: testBundlePath,
      environment: .other,
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
