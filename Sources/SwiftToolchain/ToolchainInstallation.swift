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
import TSCBasic
import TSCUtility

private let expectedArchiveSize = 891_856_371

extension FileDownloadDelegate.Progress {
  fileprivate var totalOrEstimatedBytes: Int {
    totalBytes ?? expectedArchiveSize
  }
}

extension ToolchainSystem {
  func installSDK(
    version: String,
    from url: Foundation.URL,
    to sdkPath: AbsolutePath,
    _ client: HTTPClient,
    _ terminal: InteractiveWriter
  ) async throws -> AbsolutePath {
    if !fileSystem.exists(sdkPath, followSymlink: true) {
      try fileSystem.createDirectory(sdkPath, recursive: true)
    }

    guard fileSystem.isDirectory(sdkPath) else {
      throw ToolchainError.directoryDoesNotExist(sdkPath)
    }

    let ext = url.pathExtension

    let archivePath = sdkPath.appending(component: "\(version).\(ext)")

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
        path: archivePath.pathString,
        url,
        client,
        onTotalBytes: {
          terminal.write("Archive size is \($0 / 1_000_000) MB\n", inColor: .yellow)
        }
      )

      let animation = PercentProgressAnimation(
        stream: stdoutStream,
        header: "Downloading the archive"
      )
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
          text: "saving to \(archivePath.pathString)"
        )
      }
    } catch {
      terminal.write("Download failed with error \(error)\n", inColor: .red)
      throw error
    }

    terminal.write("Download completed successfully\n", inColor: .green)

    let installationPath: AbsolutePath

    let arguments: [String]
    if ext == "pkg" {
      guard let resolver = userXCToolchainResolver else {
        throw ToolchainError.noInstallationDirectory(path: "~/Library")
      }
      installationPath = resolver.toolchain(for: version)
      arguments = [
        "installer", "-target", "CurrentUserHomeDirectory", "-pkg", archivePath.pathString,
      ]
    } else {
      installationPath = sdkPath.appending(component: version)
      try fileSystem.createDirectory(installationPath, recursive: true)

      arguments = [
        "tar", "xzf", archivePath.pathString, "--strip-components=1",
        "--directory", installationPath.pathString,
      ]
    }
    terminal.logLookup("Unpacking the archive: ", arguments.joined(separator: " "))
    _ = try processDataOutput(arguments)

    return installationPath
  }
}
