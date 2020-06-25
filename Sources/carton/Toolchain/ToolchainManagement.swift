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
import Foundation
import OpenCombine
import TSCBasic
import TSCUtility

func processStringOutput(_ arguments: [String]) throws -> String? {
  try ByteString(processDataOutput(arguments)).validDescription
}

// swiftlint:disable:next force_try
private let versionRegEx = try! RegEx(pattern: "(?:swift-)?(.+-a)-.+\\.tar.gz")

private let expectedArchiveSize = 891_856_371

enum ToolchainError: Error, CustomStringConvertible {
  case directoryDoesNotExist(AbsolutePath)
  case invalidResponseCode(UInt)
  case invalidInstallationArchive(AbsolutePath)

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
    }
  }
}

extension FileSystem {
  private func inferSwiftVersion(
    from versionSpec: String? = nil,
    _ terminal: TerminalController
  ) throws -> String {
    if let versionSpec = versionSpec {
      if let url = URL(string: versionSpec),
        let filename = url.pathComponents.last,
        let match = versionRegEx.matchGroups(in: filename).first?.first {
        terminal.logLookup("Inferred swift version: ", match)
        return match
      } else {
        return versionSpec
      }
    }

    guard let cwd = currentWorkingDirectory else { return defaultToolchainVersion }

    let versionFile = cwd.appending(component: ".swift-version")

    guard isFile(versionFile), let version = try readFileContents(versionFile)
      .validDescription?
      // get the first line of the file
      .components(separatedBy: CharacterSet.newlines).first,
      version.contains("wasm")
    else { return defaultToolchainVersion }

    return version
  }

  /** Infer `swift` binary path matching a given version if any is present, or infer the
   version from the `.swift-version` file. If neither version is installed, download it.
   */
  func inferSwiftPath(versionSpec: String? = nil, _ terminal: TerminalController) throws -> String {
    let specURL = versionSpec.flatMap { (string: String) -> Foundation.URL? in
      guard
        let url = Foundation.URL(string: string),
        let scheme = url.scheme,
        ["http", "https"].contains(scheme)
      else { return nil }
      return url
    }

    let swiftVersion = try inferSwiftVersion(from: versionSpec, terminal)

    func checkAndLog(_ prefix: AbsolutePath) throws -> String? {
      let swiftPath = prefix.appending(components: swiftVersion, "usr", "bin", "swift")

      guard isFile(swiftPath) else { return nil }

      terminal.write("Inferring basic settings...\n", inColor: .yellow)
      terminal.logLookup("- swift executable: ", swiftPath)
      if let output = try processStringOutput([swiftPath.pathString, "--version"]) {
        terminal.write(output)
      }

      return swiftPath.pathString
    }

    if let path = try checkAndLog(homeDirectory.appending(components: ".swiftenv", "versions")) {
      return path
    }

    let sdkPath = homeDirectory.appending(components: ".carton", "sdk")
    if let path = try checkAndLog(sdkPath) {
      return path
    }

    func inferDownloadURL(from version: String) -> Foundation.URL? {
      // FIXME: these platform names are not specific enough, need smarter checking here
      #if os(macOS)
      let platformSuffix = "osx"
      #elseif os(Linux)
      let platformSuffix = "linux"
      #endif
      return URL(string: """
      https://github.com/swiftwasm/swift/releases/download/\
      swift-\(version)/swift-\(version)-\(platformSuffix).tar.gz
      """)
    }

    let downloadURL: Foundation.URL

    if let specURL = specURL {
      downloadURL = specURL
    } else if let inferredURL = inferDownloadURL(from: swiftVersion) {
      downloadURL = inferredURL
    } else {
      fatalError("Failed to infer download URL for version \(swiftVersion)")
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
      terminal
    )

    guard let path = try checkAndLog(sdkPath) else {
      throw ToolchainError.invalidInstallationArchive(installationPath)
    }

    return path
  }

  func installSDK(
    version: String,
    from url: Foundation.URL,
    to sdkPath: AbsolutePath,
    _ terminal: TerminalController
  ) throws -> AbsolutePath {
    if !exists(sdkPath, followSymlink: true) {
      try createDirectory(sdkPath, recursive: true)
    }

    guard isDirectory(sdkPath) else {
      throw ToolchainError.directoryDoesNotExist(sdkPath)
    }

    let subject = PassthroughSubject<Progress, Error>()
    let archivePath = sdkPath.appending(component: "\(version).tar.gz")
    let delegate = try FileDownloadDelegate(
      path: archivePath.pathString,
      reportHead: {
        guard $0.status != .ok else { return }

        subject.send(completion: .failure(ToolchainError.invalidResponseCode($0.status.code)))
      },
      reportProgress: {
        subject.send(.init(
          step: $1,
          total: $0 ?? expectedArchiveSize,
          text: "saving to \(archivePath)"
        ))
      }
    )

    var subscriptions = [AnyCancellable]()

    let client = HTTPClient(eventLoopGroupProvider: .createNew)
    let request = try HTTPClient.Request(url: url)
    // swiftlint:disable:next force_try
    defer { try! client.syncShutdown() }

    _ = try await { (completion: @escaping (Result<(), Error>) -> ()) in
      client.execute(request: request, delegate: delegate).futureResult.whenComplete { _ in
        subject.send(completion: .finished)
      }

      subject
        .handle(
          with: PercentProgressAnimation(
            stream: stdoutStream,
            header: "Downloading the archive"
          ),
          terminal
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

  func inferBinPath(swiftPath: String) throws -> AbsolutePath {
    guard
      let output = try processStringOutput([
        swiftPath, "build", "--triple", "wasm32-unknown-wasi", "--show-bin-path",
      ])?.components(separatedBy: CharacterSet.newlines),
      let binPath = output.first
    else { fatalError("failed to decode UTF8 output of the `swift build` invocation") }

    return AbsolutePath(binPath)
  }
}
