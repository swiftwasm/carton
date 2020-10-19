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
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif
import TSCBasic
import TSCUtility

public func processStringOutput(_ arguments: [String]) throws -> String? {
  try ByteString(processDataOutput(arguments)).validDescription
}

// swiftlint:disable:next force_try
private let versionRegEx = try! RegEx(pattern: "(?:swift-)?(.+-.)-.+\\.tar.gz")

private let expectedArchiveSize = 891_856_371

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

extension FileSystem {
  private var swiftenvVersionsPath: AbsolutePath {
    homeDirectory.appending(components: ".swiftenv", "versions")
  }

  private var cartonSDKPath: AbsolutePath {
    homeDirectory.appending(components: ".carton", "sdk")
  }

  public var swiftVersionPath: AbsolutePath {
    guard let cwd = currentWorkingDirectory else {
      fatalError()
    }

    return cwd.appending(component: ".swift-version")
  }

  private func getDirectoryPaths(_ directoryPath: AbsolutePath) throws -> [AbsolutePath] {
    if isDirectory(directoryPath) {
      return try getDirectoryContents(directoryPath).map { directoryPath.appending(component: $0) }
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
    swiftVersion: String,
    _ prefix: AbsolutePath,
    _ terminal: InteractiveWriter
  ) throws -> AbsolutePath? {
    let swiftPath = prefix.appending(components: swiftVersion, "usr", "bin", "swift")

    guard isFile(swiftPath) else { return nil }

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
    let release = try await {
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
    let releaseFile = AbsolutePath("/etc/lsb-release")
    guard isFile(releaseFile) else {
      throw ToolchainError.unsupportedOperatingSystem
    }

    let releaseData = try readFileContents(releaseFile).description
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

  public func inferDestinationPath(
    for version: String,
    swiftPath: AbsolutePath
  ) throws -> AbsolutePath {
    let sdkPath = cartonSDKPath

    if !isDirectory(sdkPath) {
      try createDirectory(sdkPath, recursive: true)
    }

    let destinationPath = sdkPath.appending(component: "\(version).json")

    guard !isFile(destinationPath) else {
      return destinationPath
    }

    let sdkRoot = swiftPath.parentDirectory.parentDirectory
    let wasiSysroot = sdkRoot.appending(components: "share", "wasi-sysroot")
    let binDir = sdkRoot.appending(component: "bin")
    let wasm32Dir = sdkRoot.appending(components: "lib", "swift", "wasi", "wasm32")
    let includeFlags = ["-I", wasm32Dir.pathString]

    let destination = Destination(
      sdk: wasiSysroot,
      toolchainBinDir: binDir,
      extraCCFlags: includeFlags,
      extraSwiftcFlags: includeFlags + [
        "-Xlinker",
        "-lFoundation",
        "-Xlinker",
        "-lCoreFoundation",
        "-Xlinker",
        "-lBlocksRuntime",
        "-Xlinker",
        "-licui18n",
        "-Xlinker",
        "-luuid",
      ]
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted

    let data = try encoder.encode(destination)
    try data.write(to: destinationPath.asURL)

    return destinationPath
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

    if let path = try checkAndLog(swiftVersion: swiftVersion, swiftenvVersionsPath, terminal) {
      return (path, swiftVersion)
    }

    let sdkPath = cartonSDKPath
    if let path = try checkAndLog(swiftVersion: swiftVersion, sdkPath, terminal) {
      return (path, swiftVersion)
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
      to: sdkPath,
      client,
      terminal
    )

    guard let path = try checkAndLog(swiftVersion: swiftVersion, sdkPath, terminal) else {
      throw ToolchainError.invalidInstallationArchive(installationPath)
    }

    return (path, swiftVersion)
  }

  private func downloadDelegate(
    path: String,
    _ terminal: InteractiveWriter
  ) throws -> (FileDownloadDelegate, PassthroughSubject<Progress, Error>) {
    let subject = PassthroughSubject<Progress, Error>()
    return try (FileDownloadDelegate(
      path: path,
      reportHead: {
        guard $0.status == .ok,
          let totalBytes = $0.headers.first(name: "Content-Length").flatMap(Int.init)
        else {
          subject.send(completion: .failure(ToolchainError.invalidResponseCode($0.status.code)))
          return
        }
        terminal.write("Archive size is \(totalBytes / 1_000_000) MB\n", inColor: .yellow)
      },
      reportProgress: {
        subject.send(.init(
          step: $1,
          total: $0 ?? expectedArchiveSize,
          text: "saving to \(path)"
        ))
      }
    ), subject)
  }

  private func installSDK(
    version: String,
    from url: Foundation.URL,
    to sdkPath: AbsolutePath,
    _ client: HTTPClient,
    _ terminal: InteractiveWriter
  ) throws -> AbsolutePath {
    if !exists(sdkPath, followSymlink: true) {
      try createDirectory(sdkPath, recursive: true)
    }

    guard isDirectory(sdkPath) else {
      throw ToolchainError.directoryDoesNotExist(sdkPath)
    }

    let archivePath = sdkPath.appending(component: "\(version).tar.gz")
    let (delegate, subject) = try downloadDelegate(path: archivePath.pathString, terminal)

    var subscriptions = [AnyCancellable]()
    let request = try HTTPClient.Request.get(url: url)

    _ = try await { (completion: @escaping (Result<(), Error>) -> ()) in
      client.execute(request: request, delegate: delegate).futureResult.whenComplete { _ in
        subject.send(completion: .finished)
      }

      subject
        .removeDuplicates {
          // only report values that differ in more than 1%
          $1.step - $0.step < ($0.total / 100)
        }
        .handle(
          with: PercentProgressAnimation(stream: stdoutStream, header: "Downloading the archive")
        )
        .sink(
          receiveCompletion: {
            switch $0 {
            case .finished:
              terminal.write("Download completed successfully\n", inColor: .green)
              completion(.success(()))
            case let .failure(error):
              terminal.write("Download failed\n", inColor: .red)
              completion(.failure(error))
            }
          },
          receiveValue: { _ in }
        )
        .store(in: &subscriptions)
    }

    let installationPath = sdkPath.appending(component: version)

    try createDirectory(installationPath, recursive: true)

    let arguments = [
      "tar", "xzf", archivePath.pathString, "--strip-components=1",
      "--directory", installationPath.pathString,
    ]
    terminal.logLookup("Unpacking the archive: ", arguments.joined(separator: " "))
    _ = try processDataOutput(arguments)

    try removeFileTree(archivePath)

    return installationPath
  }

  public func fetchAllSwiftVersions() throws -> [String] {
    var result = [String]()

    if isDirectory(cartonSDKPath) {
      try result.append(contentsOf: getDirectoryPaths(cartonSDKPath)
        .filter { isDirectory($0) }.map(\.basename))
    }

    if isDirectory(swiftenvVersionsPath) {
      try result.append(contentsOf: getDirectoryPaths(swiftenvVersionsPath)
        .filter { isDirectory($0) }.map(\.basename))
    }

    return result.sorted()
  }

  public func fetchLocalSwiftVersion() throws -> String? {
    guard isFile(swiftVersionPath), let version = try readFileContents(swiftVersionPath)
      .validDescription?
      // get the first line of the file
      .components(separatedBy: CharacterSet.newlines).first
    else { return nil }

    return version
  }

  public func setLocalSwiftVersion(_ version: String) throws {
    try writeFileContents(swiftVersionPath, bytes: ByteString([UInt8](version.utf8)))
  }
}
