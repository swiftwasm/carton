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

private let expectedArchiveSize = 891_856_371

extension ToolchainSystem {
  func installSDK(
    version: String,
    from url: Foundation.URL,
    to sdkPath: AbsolutePath,
    _ client: HTTPClient,
    _ terminal: InteractiveWriter
  ) throws -> AbsolutePath {
    if !fileSystem.exists(sdkPath, followSymlink: true) {
      try fileSystem.createDirectory(sdkPath, recursive: true)
    }

    guard fileSystem.isDirectory(sdkPath) else {
      throw ToolchainError.directoryDoesNotExist(sdkPath)
    }

    let ext = url.pathExtension

    let archivePath = sdkPath.appending(component: "\(version).\(ext)")
    let (delegate, subject) = try downloadDelegate(path: archivePath.pathString, terminal)

    var subscriptions = [AnyCancellable]()
    let request = try HTTPClient.Request.get(url: url)

    _ = try tsc_await { (completion: @escaping (Result<(), Error>) -> ()) in
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

    try fileSystem.removeFileTree(archivePath)

    return installationPath
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
          step: $0.receivedBytes,
          total: $0.totalBytes ?? expectedArchiveSize,
          text: "saving to \(path)"
        ))
      }
    ), subject)
  }
}
