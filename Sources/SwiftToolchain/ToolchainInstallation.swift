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

private let expectedArchiveSize = 891_856_371

extension AsyncFileDownload.Progress {
  fileprivate var totalOrEstimatedBytes: Int {
    totalBytes ?? expectedArchiveSize
  }
}

extension ToolchainSystem {
  func installSDK(
    version: String,
    from url: Foundation.URL,
    to sdkPath: Foundation.URL,
    _ terminal: InteractiveWriter
  ) async throws -> URL {
    if !fileSystem.fileExists(atPath: sdkPath.path) {
      try fileSystem.createDirectory(at: sdkPath, withIntermediateDirectories: true)
    }

    guard fileSystem.isDirectory(at: sdkPath) else {
      throw ToolchainError.directoryDoesNotExist(sdkPath)
    }

    let ext = url.pathExtension

    let archivePath = sdkPath.appendingPathComponent("\(version).\(ext)")

    // Clean up the downloaded file (especially important for failed downloads, otherwise running
    // `carton` again will fail trying to pick up the broken download).
    defer {
      do {
        try fileSystem.removeFileTree(archivePath)
      } catch {
        terminal.write("Failed to remove downloaded file with error \(error)\n", inColor: .red)
      }
    }

    do {
      let fileDownload = AsyncFileDownload(
        path: archivePath.path,
        url,
        onTotalBytes: {
          terminal.write("Archive size is \($0 / 1_000_000) MB\n", inColor: .yellow)
        }
      )

      let animation = PercentProgressAnimation(
        stream: .stdout,
        header: "Downloading the archive"
      )
      defer { terminal.write("\n") }
      
      var previouslyReceived = 0
      for try await progress in fileDownload.progressStream {
        guard progress.receivedBytes - previouslyReceived >= (progress.totalOrEstimatedBytes / 100)
        else {
          continue
        }
        defer { previouslyReceived = progress.receivedBytes }

        animation.update(
          step: progress.receivedBytes,
          total: progress.totalOrEstimatedBytes,
          text: "saving to \(archivePath.path)"
        )
      }
    } catch {
      terminal.write("Download failed with error \(error)\n", inColor: .red)
      throw error
    }

    terminal.write("Download completed successfully\n", inColor: .green)

    let installationPath: URL

    let executableURL: URL
    let arguments: [String]
    if ext == "pkg" {
      guard let resolver = userXCToolchainResolver else {
        throw ToolchainError.noInstallationDirectory(path: "~/Library")
      }
      installationPath = resolver.toolchain(for: version)
      executableURL = URL(fileURLWithPath: "/usr/sbin/installer")
      arguments = [
        "-target", "CurrentUserHomeDirectory", "-pkg", archivePath.path,
      ]
    } else {
      installationPath = sdkPath.appendingPathComponent(version)
      try fileSystem.createDirectory(at: installationPath, withIntermediateDirectories: true)

      executableURL = try Process.which("tar")
      arguments = [
        "xzf", archivePath.path, "--strip-components=1",
        "--directory", installationPath.path,
      ]
    }
    terminal.logLookup("Unpacking the archive: ", ([executableURL.path] + arguments).joined(separator: " "))
    try Process.checkRun(executableURL, arguments: arguments)

    return installationPath
  }

  func patchSnapshotForMac(path: URL, terminal: InteractiveWriter) async throws {
    let binDir = path.appendingPathComponent("usr").appendingPathComponent("bin")
    
    terminal.write(
      "To avoid issues with the snapshot, the toolchain will be re-signed.\n",
      inColor: .yellow
    )
    
    for file in try fileSystem.traverseRecursively(binDir) {
      guard fileSystem.isFile(file) else { continue }
      
      try Foundation.Process.checkRun(
        URL(fileURLWithPath: "/usr/bin/codesign"),
        arguments: [
          "--force",
          "--preserve-metadata=identifier,entitlements",
          "--sign", "-", file.path
        ]
      )
    }
  }
}

extension FileManager {
  func isDirectory(at url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    let exists: Bool = FileManager.default.fileExists(
      atPath: url.path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
  }
  func isFile(_ path: URL) -> Bool {
    let attrs = try? FileManager.default.attributesOfItem(atPath: path.path)
    return attrs?[.type] as? FileAttributeType == .typeRegular
  }
  func removeFileTree(_ path: URL) throws {
    do {
      try FileManager.default.removeItem(atPath: path.path)
    } catch let error as NSError {
      // If we failed because the directory doesn't actually exist anymore, ignore the error.
      if !(error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError) {
        throw error
      }
    }
  }
}
