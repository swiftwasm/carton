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
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

internal func processStringOutput(_ arguments: [String]) throws -> String? {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: arguments[0])
  process.arguments = Array(arguments.dropFirst())
  let pipe = Pipe()
  process.standardOutput = pipe
  try process.run()
  process.waitUntilExit()
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  return String(data: data, encoding: .utf8)
}

private let versionRegEx = #/(?:swift-)?(.+-.)-.+\\.tar.gz/#

private struct Release: Decodable {
  struct Asset: Decodable {
    enum CodingKeys: String, CodingKey {
      case name
      case url = "browser_download_url"
    }

    let name: String
    let url: Foundation.URL
  }

  let assets: [Asset]
}

public class ToolchainSystem {
  let fileSystem: FileSystem
  let userXCToolchainResolver: XCToolchainResolver?
  let cartonToolchainResolver: CartonToolchainResolver
  let resolvers: [ToolchainResolver]

  public init(fileSystem: FileSystem) throws {
    self.fileSystem = fileSystem

    let userLibraryPath = NSSearchPathForDirectoriesInDomains(
      .libraryDirectory,
      .userDomainMask,
      true
    ).first
    let rootLibraryPath = NSSearchPathForDirectoriesInDomains(
      .libraryDirectory,
      .localDomainMask,
      true
    ).first
    userXCToolchainResolver = try userLibraryPath.flatMap {
      XCToolchainResolver(libraryPath: try AbsolutePath(validating: $0), fileSystem: fileSystem)
    }
    let rootXCToolchainResolver = try rootLibraryPath.flatMap {
      XCToolchainResolver(libraryPath: try AbsolutePath(validating: $0), fileSystem: fileSystem)
    }
    let xctoolchainResolvers: [ToolchainResolver] = [
      userXCToolchainResolver, rootXCToolchainResolver,
    ].compactMap { $0 }

    cartonToolchainResolver = try CartonToolchainResolver(fileSystem: fileSystem)
    resolvers =
      try [
        cartonToolchainResolver,
        SwiftEnvToolchainResolver(fileSystem: fileSystem),
      ] + xctoolchainResolvers
  }

  private var libraryPaths: [AbsolutePath] {
    get throws {
      try NSSearchPathForDirectoriesInDomains(
        .libraryDirectory, [.localDomainMask], true
      ).map { try AbsolutePath(validating: $0) }
    }
  }

  public var swiftVersionPath: AbsolutePath {
    guard let cwd = fileSystem.currentWorkingDirectory else {
      fatalError()
    }

    return cwd.appending(component: ".swift-version")
  }

  private func getDirectoryPaths(_ directoryPath: AbsolutePath) throws -> [AbsolutePath] {
    if fileSystem.isDirectory(directoryPath) {
      return try fileSystem.getDirectoryContents(directoryPath)
        .map { directoryPath.appending(component: $0) }
    } else {
      return []
    }
  }

  func inferSwiftVersion(
    from versionSpec: String? = nil,
    _ terminal: InteractiveWriter
  ) throws -> String {
    if let versionSpec = versionSpec {
      if let url = URL(string: versionSpec),
        let filename = url.pathComponents.last,
        let match = try versionRegEx.firstMatch(in: filename)?.0
      {
        terminal.logLookup("Inferred swift version: ", match)
        return String(match)
      } else {
        return versionSpec
      }
    }

    guard let version = try fetchLocalSwiftVersion(), version.contains("wasm") else {
      return defaultToolchainVersion
    }

    return version
  }

  private func checkAndLog(
    installationPath: AbsolutePath,
    _ terminal: InteractiveWriter
  ) throws -> AbsolutePath? {
    let swiftPath = installationPath.appending(components: "usr", "bin", "swift")

    terminal.logLookup("- checking Swift compiler path: ", swiftPath)
    guard fileSystem.exists(swiftPath, followSymlink: true) else { return nil }

    terminal.write("Inferring basic settings...\n", inColor: .yellow)
    terminal.logLookup("- swift executable: ", swiftPath)
    if let output = try processStringOutput([swiftPath.pathString, "--version"]) {
      terminal.write(output)
    }

    return swiftPath
  }

  private func inferDownloadURL(
    from version: String,
    _ client: URLSession,
    _ terminal: InteractiveWriter
  ) async throws -> Foundation.URL? {
    let releaseURL = """
      https://api.github.com/repos/swiftwasm/swift/releases/tags/\
      swift-\(version)
      """

    terminal.logLookup("Fetching release assets from ", releaseURL)
    let decoder = JSONDecoder()
    let request = URLRequest(url: URL(string: releaseURL)!)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ToolchainError.invalidResponse(url: releaseURL, status: -1)
    }
    guard 200..<300 ~= httpResponse.statusCode else {
      throw ToolchainError.invalidResponse(url: releaseURL, status: httpResponse.statusCode)
    }
    terminal.write("Response contained body, parsing it now...\n", inColor: .green)

    let release = try decoder.decode(Release.self, from: data)

    #if arch(x86_64)
      let archSuffix = "x86_64"
    #elseif arch(arm64)
      #if os(macOS)
        let archSuffix = "arm64"
      #elseif os(Linux)
        let archSuffix = "aarch64"
      #endif
    #endif

    #if os(macOS)
      let platformSuffixes = ["osx", "catalina", "macos"]
    #elseif os(Linux)
      let platformSuffixes = ["linux", try self.inferLinuxDistributionSuffix()]
    #endif

    terminal.logLookup(
      "Response succesfully parsed, choosing from this number of assets: ",
      release.assets.count
    )
    let nameSuffixes = platformSuffixes.map { "\($0)_\(archSuffix)" }
    return release.assets.map(\.url).filter { url in
      nameSuffixes.contains { url.absoluteString.contains($0) }
        && !url.absoluteString.contains(".artifactbundle.")
    }.first
  }

  private func inferLinuxDistributionSuffix() throws -> String {
    guard
      let releaseFile = [
        AbsolutePath.root.appending(components: "etc", "lsb-release"),
        AbsolutePath.root.appending(components: "etc", "os-release"),
      ].first(where: fileSystem.isFile)
    else {
      throw ToolchainError.unsupportedOperatingSystem
    }

    let releaseData = try fileSystem.readFileContents(releaseFile).description
    if releaseData.contains("DISTRIB_RELEASE=18.04") {
      return "ubuntu18.04"
    } else if releaseData.contains("DISTRIB_RELEASE=20.04") {
      return "ubuntu20.04"
    } else if releaseData.contains("DISTRIB_RELEASE=22.04") {
      return "ubuntu22.04"
    } else if releaseData.contains(#"PRETTY_NAME="Amazon Linux 2""#) {
      return "amazonlinux2"
    } else {
      throw ToolchainError.unsupportedOperatingSystem
    }
  }

  /** Infer `swift` binary path matching a given version if any is present, or infer the
   version from the `.swift-version` file. If neither version is installed, download it.
   */
  public func inferSwiftPath(
    from versionSpec: String? = nil,
    _ terminal: InteractiveWriter
  ) async throws -> (AbsolutePath, String) {
    let specURL = versionSpec.flatMap { (string: String) -> Foundation.URL? in
      guard
        let url = Foundation.URL(string: string),
        let scheme = url.scheme,
        ["http", "https"].contains(scheme)
      else { return nil }
      return url
    }

    let swiftVersion = try inferSwiftVersion(from: versionSpec, terminal)

    for resolver in resolvers {
      if let path = try checkAndLog(
        installationPath: resolver.toolchain(for: swiftVersion),
        terminal
      ) {
        return (path, swiftVersion)
      }
    }

    let client = URLSession.shared

    let downloadURL: Foundation.URL

    if let specURL = specURL {
      downloadURL = specURL
    } else if let inferredURL = try await inferDownloadURL(from: swiftVersion, client, terminal) {
      downloadURL = inferredURL
    } else {
      terminal.write("The Swift version \(swiftVersion) was not found\n", inColor: .red)
      throw ToolchainError.invalidVersion(version: swiftVersion)
    }

    terminal.write(
      "Local installation of Swift version \(swiftVersion) not found\n",
      inColor: .yellow
    )
    terminal.logLookup("Swift toolchain/SDK download URL: ", downloadURL)
    let installationPath = try await installSDK(
      version: swiftVersion,
      from: downloadURL,
      to: cartonToolchainResolver.cartonSDKPath,
      terminal
    )

    guard let path = try checkAndLog(installationPath: installationPath, terminal) else {
      throw ToolchainError.invalidInstallationArchive(installationPath)
    }

    return (path, swiftVersion)
  }

  public func fetchAllSwiftVersions() throws -> [String] {
    resolvers.flatMap { (try? $0.fetchVersions()) ?? [] }
      .filter { fileSystem.isDirectory($0.path) }
      .map(\.version)
      .sorted()
  }

  public func fetchLocalSwiftVersion() throws -> String? {
    guard fileSystem.isFile(swiftVersionPath),
      let version = try fileSystem.readFileContents(swiftVersionPath)
        .validDescription?
        // get the first line of the file
        .components(separatedBy: CharacterSet.newlines).first
    else { return nil }

    return version
  }
}
