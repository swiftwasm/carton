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

import CartonCore
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

enum ToolchainError: Error, CustomStringConvertible {
  case directoryDoesNotExist(URL)
  case invalidInstallationArchive(URL)
  case invalidVersion(version: String)
  case notHTTPURLResponse(url: String)
  case invalidResponse(url: String, status: Int, body: Data)
  case unsupportedOperatingSystem
  case noInstallationDirectory(path: String)

  var description: String {
    switch self {
    case let .directoryDoesNotExist(path):
      return "Directory at path \(path.path) does not exist and could not be created"
    case let .invalidInstallationArchive(path):
      return "Invalid toolchain/SDK archive was installed at path \(path)"
    case let .invalidVersion(version):
      return "Invalid version \(version)"
    case let .notHTTPURLResponse(url: url):
      return "Response from \(url) is not HTTPURLResponse"
    case let .invalidResponse(url: url, status: status, body: body):
      var t = "Response from \(url) had invalid status \(status) with a body of \(body.count) bytes: "
      t += String(decoding: body, as: UTF8.self)
      return t
    case .unsupportedOperatingSystem:
      return "This version of the operating system is not supported"
    case let .noInstallationDirectory(path):
      return """
        Failed to infer toolchain installation directory. Please make sure that \(path) exists.
        """
    }
  }
}

public class ToolchainSystem {
  let fileSystem: FileManager
  let userXCToolchainResolver: XCToolchainResolver?
  let cartonToolchainResolver: CartonToolchainResolver
  let resolvers: [ToolchainResolver]
  let githubToken: String?

  public init(
    fileSystem: FileManager,
    githubToken: String? = nil
  ) throws {
    self.fileSystem = fileSystem
    self.githubToken = githubToken ?? ProcessInfo.processInfo.environment["GITHUB_TOKEN"]

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
      XCToolchainResolver(libraryPath: URL(fileURLWithPath: $0), fileSystem: fileSystem)
    }
    let rootXCToolchainResolver = rootLibraryPath.flatMap {
      XCToolchainResolver(libraryPath: URL(fileURLWithPath: $0), fileSystem: fileSystem)
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

  public var swiftVersionPath: URL {
    let cwd = URL(fileURLWithPath: fileSystem.currentDirectoryPath)
    return cwd.appendingPathComponent(".swift-version")
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
    installationPath: URL,
    _ terminal: InteractiveWriter
  ) throws -> URL? {
    let swiftPath = installationPath
      .appendingPathComponent("usr")
      .appendingPathComponent("bin")
      .appendingPathComponent("swift")

    terminal.logLookup("- checking Swift compiler path: ", swiftPath.path)
    guard fileSystem.fileExists(atPath: swiftPath.path) else { return nil }

    terminal.write("Inferring basic settings...\n", inColor: .yellow)
    terminal.logLookup("- swift executable: ", swiftPath.path)
    if let output = try processStringOutput([swiftPath.path, "--version"]) {
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
    var request = URLRequest(url: URL(string: releaseURL)!)
    if let githubToken {
      request.setValue("Bearer \(githubToken)", forHTTPHeaderField: "Authorization")
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ToolchainError.notHTTPURLResponse(url: releaseURL)
    }
    guard 200..<300 ~= httpResponse.statusCode else {
      throw ToolchainError.invalidResponse(
        url: releaseURL, status: httpResponse.statusCode, body: data
      )
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
      "Response successfully parsed, choosing from this number of assets: ",
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
        URL(fileURLWithPath: "/etc/lsb-release"),
        URL(fileURLWithPath: "/etc/os-release"),
      ].first(where: fileSystem.isFile)
    else {
      throw ToolchainError.unsupportedOperatingSystem
    }

    let releaseData = try String(contentsOf: releaseFile)
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

  public struct SwiftPath {
    public var version: String
    public var swift: URL
    public var toolchain: URL
  }

  /** Infer `swift` binary path matching a given version if any is present, or infer the
   version from the `.swift-version` file. If neither version is installed, download it.
   */
  public func inferSwiftPath(
    from versionSpec: String? = nil,
    _ terminal: InteractiveWriter
  ) async throws -> SwiftPath {
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
      let toolchain = resolver.toolchain(for: swiftVersion)
      if let path = try checkAndLog(installationPath: toolchain, terminal) {
        return SwiftPath(version: swiftVersion, swift: path, toolchain: toolchain)
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

    return SwiftPath(version: swiftVersion, swift: path, toolchain: installationPath)
  }

  public func fetchAllSwiftVersions() throws -> [String] {
    resolvers.flatMap { (try? $0.fetchVersions()) ?? [] }
      .filter { fileSystem.isDirectory(at: $0.path) }
      .map(\.version)
      .sorted()
  }

  public func fetchLocalSwiftVersion() throws -> String? {
    guard fileSystem.isFile(swiftVersionPath),
          let version = try String(contentsOf: swiftVersionPath)
            // get the first line of the file
      .components(separatedBy: CharacterSet.newlines).first
    else { return nil }

    return version
  }

  public static func isSnapshotVersion(_ version: String) -> Bool {
    version.contains("SNAPSHOT")
  }
}
