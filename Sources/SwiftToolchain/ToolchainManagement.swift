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

import AsyncHTTPClient
import CartonHelpers
import Foundation
import NIOFoundationCompat
import TSCBasic
import TSCUtility

public func processStringOutput(_ arguments: [String]) throws -> String? {
  try ByteString(processDataOutput(arguments)).validDescription
}

// swiftlint:disable:next force_try
private let versionRegEx = try! RegEx(pattern: "(?:swift-)?(.+-.)-.+\\.tar.gz")

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

  public init(fileSystem: FileSystem) {
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
    userXCToolchainResolver = userLibraryPath.flatMap {
      XCToolchainResolver(libraryPath: AbsolutePath($0), fileSystem: fileSystem)
    }
    let rootXCToolchainResolver = rootLibraryPath.flatMap {
      XCToolchainResolver(libraryPath: AbsolutePath($0), fileSystem: fileSystem)
    }
    let xctoolchainResolvers: [ToolchainResolver] = [
      userXCToolchainResolver, rootXCToolchainResolver,
    ].compactMap { $0 }

    cartonToolchainResolver = CartonToolchainResolver(fileSystem: fileSystem)
    resolvers = [
      cartonToolchainResolver,
      SwiftEnvToolchainResolver(fileSystem: fileSystem),
    ] + xctoolchainResolvers
  }

  private var libraryPaths: [AbsolutePath] {
    NSSearchPathForDirectoriesInDomains(
      .libraryDirectory, [.localDomainMask], true
    ).map { AbsolutePath($0) }
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
         let match = versionRegEx.matchGroups(in: filename).first?.first
      {
        terminal.logLookup("Inferred swift version: ", match)
        return match
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
    guard fileSystem.isFile(swiftPath) else { return nil }

    terminal.write("Inferring basic settings...\n", inColor: .yellow)
    terminal.logLookup("- swift executable: ", swiftPath)
    if let output = try processStringOutput([swiftPath.pathString, "--version"]) {
      terminal.write(output)
    }

    return swiftPath
  }

  private func inferDownloadURL(
    from version: String,
    _ client: HTTPClient,
    _ terminal: InteractiveWriter
  ) throws -> Foundation.URL? {
    let releaseURL = """
    https://api.github.com/repos/swiftwasm/swift/releases/tags/\
    swift-\(version)
    """

    terminal.logLookup("Fetching release assets from ", releaseURL)
    let decoder = JSONDecoder()
    let request = try HTTPClient.Request.get(url: releaseURL)
    let release = try tsc_await {
      client.execute(request: request).flatMapResult { response -> Result<Release, Error> in
        guard (200..<300).contains(response.status.code), let body = response.body else {
          return .failure(ToolchainError.invalidResponse(
            url: releaseURL,
            status: response.status.code
          ))
        }
        terminal.write("Response contained body, parsing it now...\n", inColor: .green)

        return Result { try decoder.decode(Release.self, from: body) }
      }.whenComplete($0)
    }

    #if os(macOS)
    let platformSuffixes = ["osx", "catalina", "macos"]
    #elseif os(Linux)
    let releaseFile = AbsolutePath("/etc").appending(component: "lsb-release")
    guard fileSystem.isFile(releaseFile) else {
      throw ToolchainError.unsupportedOperatingSystem
    }

    let releaseData = try fileSystem.readFileContents(releaseFile).description
    let ubuntuSuffix: String
    if releaseData.contains("DISTRIB_RELEASE=18.04") {
      ubuntuSuffix = "ubuntu18.04"
    } else if releaseData.contains("DISTRIB_RELEASE=20.04") {
      ubuntuSuffix = "ubuntu20.04"
    } else {
      throw ToolchainError.unsupportedOperatingSystem
    }

    let platformSuffixes = ["linux", ubuntuSuffix]
    #endif

    terminal.logLookup(
      "Response succesfully parsed, choosing from this number of assets: ",
      release.assets.count
    )
    return release.assets.map(\.url).filter { url in
      platformSuffixes.contains { url.absoluteString.contains($0) }
    }.first
  }

  /** Infer `swift` binary path matching a given version if any is present, or infer the
   version from the `.swift-version` file. If neither version is installed, download it.
   */
  func inferSwiftPath(
    from versionSpec: String? = nil,
    _ terminal: InteractiveWriter
  ) throws -> (AbsolutePath, String) {
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

    let client = HTTPClient(eventLoopGroupProvider: .createNew)
    // swiftlint:disable:next force_try
    defer { try! client.syncShutdown() }

    let downloadURL: Foundation.URL

    if let specURL = specURL {
      downloadURL = specURL
    } else if let inferredURL = try inferDownloadURL(from: swiftVersion, client, terminal) {
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
    let installationPath = try installSDK(
      version: swiftVersion,
      from: downloadURL,
      to: cartonToolchainResolver.cartonSDKPath,
      client,
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

  public func setLocalSwiftVersion(_ version: String) throws {
    try fileSystem.writeFileContents(swiftVersionPath, bytes: ByteString([UInt8](version.utf8)))
  }
}
