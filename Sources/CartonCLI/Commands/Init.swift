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
import CartonHelpers
import CartonKit
import Foundation
import SwiftToolchain
import TSCBasic

struct Init: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Create a Swift package for a new SwiftWasm project.",
    subcommands: [ListTemplates.self]
  )

  @Option(
    name: .long,
    help: "The template to base the project on.",
    transform: { Templates(rawValue: $0.lowercased()) })
  var template: Templates?

  @Option(
    name: .long,
    help: "The name of the project") var name: String?

  func run() async throws {
    let terminal = InteractiveWriter.stdout

    guard let name = name ?? localFileSystem.currentWorkingDirectory?.basename else {
      terminal.write("Project name could not be inferred\n", inColor: .red)
      return
    }
    guard let currentDir = localFileSystem.currentWorkingDirectory else {
      terminal.write("Failed to get current working directory.\n", inColor: .red)
      return
    }
    let template = self.template ?? .basic
    terminal.write("Creating new project with template ")
    terminal.write("\(template.rawValue)", inColor: .green)
    terminal.write(" in ")
    terminal.write("\(name)\n", inColor: .cyan)

    guard
      let packagePath = self.name == nil
        ? localFileSystem.currentWorkingDirectory : AbsolutePath(name, relativeTo: currentDir)
    else {
      terminal.write("Path to project could be created.\n", inColor: .red)
      return
    }
    try localFileSystem.createDirectory(packagePath)
    try await template.template.create(
      on: localFileSystem,
      project: .init(name: name, path: packagePath, inPlace: self.name == nil),
      terminal
    )
  }
}
