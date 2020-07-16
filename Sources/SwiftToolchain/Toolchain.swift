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

enum ToolchainError: Error, CustomStringConvertible {
  case directoryDoesNotExist(AbsolutePath)
  case invalidResponseCode(UInt)
  case invalidInstallationArchive(AbsolutePath)
  case noExecutableProduct
  case failedToBuild(product: String)
  case failedToBuildTestBundle
  case missingPackage

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
    case .missingPackage:
      return "No package found"
    }
  }
}

public final class Toolchain {
  private let fileSystem: FileSystem
  private let terminal: TerminalController

  private let version: String
  private let swiftPath: AbsolutePath
  private let package: Package?

  public init(
    for versionSpec: String? = nil,
    _ fileSystem: FileSystem,
    _ terminal: TerminalController
  ) throws {
    (swiftPath, version) = try fileSystem.inferSwiftPath(from: versionSpec, terminal)
    self.fileSystem = fileSystem
    self.terminal = terminal
    package = try? Package(with: swiftPath, terminal)
  }

  private func inferBinPath() throws -> AbsolutePath {
    guard
      let output = try processStringOutput([
        swiftPath.pathString, "build", "--triple", "wasm32-unknown-wasi", "--show-bin-path",
      ])?.components(separatedBy: CharacterSet.newlines),
      let binPath = output.first
    else { fatalError("failed to decode UTF8 output of the `swift build` invocation") }

    return AbsolutePath(binPath)
  }

  private func inferDevProduct(hint: String?) throws -> String? {
    guard let package = package else {
      throw ToolchainError.missingPackage
    }
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

  public func inferSourcesPaths() throws -> [AbsolutePath] {
    let package = try Package(with: swiftPath, terminal)

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

    return try targetPaths.compactMap {
      try fileSystem.currentWorkingDirectory?.appending(RelativePath(validating: $0))
    }
  }

  private func inferDestinationPath() throws -> AbsolutePath {
    try fileSystem.inferDestinationPath(for: version, swiftPath: swiftPath)
  }

  public func buildCurrentProject(
    product: String?,
    destination: String?,
    isRelease: Bool
  ) throws -> (builderArguments: [String], mainWasmPath: AbsolutePath) {
    guard let product = try inferDevProduct(hint: product)
    else { throw ToolchainError.noExecutableProduct }

    let binPath = try inferBinPath()
    let mainWasmPath = binPath.appending(component: product)
    terminal.logLookup("- development binary to serve: ", mainWasmPath.pathString)

    terminal.write("\nBuilding the project before spinning up a server...\n", inColor: .yellow)

    let builderArguments = try [
      swiftPath.pathString, "build", "-c", isRelease ? "release" : "debug", "--product", product,
      "--enable-test-discovery", "--destination", destination ?? inferDestinationPath().pathString,
    ]

    try ProcessRunner(builderArguments, terminal).waitUntilFinished()

    guard localFileSystem.exists(mainWasmPath) else {
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
    guard let package = package else {
      throw ToolchainError.missingPackage
    }
    let binPath = try inferBinPath()
    let testBundlePath = binPath.appending(component: "\(package.name)PackageTests.xctest")
    terminal.logLookup("- test bundle to run: ", testBundlePath.pathString)

    terminal.write(
      "\nBuilding the test bundle before running the test suite...\n",
      inColor: .yellow
    )

    let builderArguments = try [
      swiftPath.pathString, "build", "-c", isRelease ? "release" : "debug", "--build-tests",
      "--destination", inferDestinationPath().pathString,
    ]

    try ProcessRunner(builderArguments, terminal).waitUntilFinished()

    guard localFileSystem.exists(testBundlePath) else {
      terminal.write(
        "Failed to build the test bundle, fix the build errors and restart\n",
        inColor: .red
      )
      throw ToolchainError.failedToBuildTestBundle
    }

    return testBundlePath
  }

  public func packageInit(name: String, type: PackageType) throws {
    try ProcessRunner([
      swiftPath.pathString, "package", "init",
      "--name", name,
      "--type", type.rawValue,
    ], terminal)
      .waitUntilFinished()
  }
}
