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
import Foundation
import SwiftToolchain
import TSCBasic

struct Init: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Create a Swift package for a new SwiftWasm project."
  )

  @Option(name: .long,
          help: "The template to base the project on.",
          transform: { Templates(rawValue: $0.lowercased()) })
  var template: Templates?

  @Flag(name: .long,
        help: "List the available templates.")
  var listTemplates: Bool = false

  @Argument() var name: String?

  func run() throws {
    guard let terminal = TerminalController(stream: stdoutStream)
    else { fatalError("failed to create an instance of `TerminalController`") }

    if listTemplates {
      Templates.allCases.forEach {
        terminal.write($0.rawValue, inColor: .green, bold: true)
        terminal.write("\t\($0.template.description)\n")
      }
    } else {
      guard let name = name else {
        terminal.write("No name specified.\n", inColor: .red)
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

      let packagePath = AbsolutePath(name, relativeTo: currentDir)
      try localFileSystem.createDirectory(packagePath)
      try template.template.create(on: localFileSystem,
                                   project: .init(name: name, path: packagePath),
                                   terminal)
    }
  }
}
