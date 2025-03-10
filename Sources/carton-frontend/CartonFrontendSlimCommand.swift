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
import CartonCore

/// A slimed-down version of the `carton-frontend` command.
/// This command does not depend on HTTP server functionality to avoid the need for
/// building large dependencies.
@main
public struct CartonFrontendSlimCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "carton-frontend",
    abstract: "📦 Watcher, bundler, and test runner for your SwiftWasm apps.",
    version: cartonVersion,
    subcommands: [
      CartonFrontendBundleCommand.self,
      CartonFrontendTestCommand.self,
      CartonFrontendDevCommand.self,
    ]
  )

  public init() {}
}
