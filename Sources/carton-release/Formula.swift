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

import ArgumentParser
import AsyncHTTPClient
import TSCBasic

struct Formula: ParsableCommand {
  @Argument() var version: String

  func run() throws {
    let archiveURL = "https://github.com/swiftwasm/carton/archive/\(version).tar.gz"

    let client = HTTPClient(eventLoopGroupProvider: .createNew)
    let response: HTTPClient.Response = try await {
      client.get(url: archiveURL).whenComplete($0)
    }
    try client.syncShutdown()

    guard
      var body = response.body,
      let bytes = body.readBytes(length: body.readableBytes)
    else { fatalError("download failed for URL \(archiveURL)") }

    let downloadedArchive = ByteString(bytes)

    let sha256 = SHA256().hash(downloadedArchive).hexadecimalRepresentation

    let formula = #"""
    class Carton < Formula
      desc "📦 Watcher, bundler, and test runner for your SwiftWasm apps"
      homepage "https://carton.dev"
      head "https://github.com/swiftwasm/carton.git"

      depends_on :xcode => "11.4"
      depends_on "wasmer"

      stable do
        version "\#(version)"
        url "https://github.com/swiftwasm/carton/archive/#{version}.tar.gz"
        sha256 "\#(sha256)"
      end

      def install
        system "swift", "build", "--disable-sandbox", "-c", "release"
        system "mv", ".build/release/carton", "carton"
        bin.install "carton"
      end

      test do
        system "carton -h"
      end
    end
    """#

    print(formula)
  }
}
