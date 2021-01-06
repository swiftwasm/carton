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

struct Init: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Create a Swift package for a new SwiftWasm project.",
    subcommands: [ListTemplates.self]
  )

  @Option(
    name: .long,
    help: "The template to base the project on.",
    transform: { Templates(rawValue: $0.lowercased()) }
  )
  var template: Templates?

  @Option(
    name: .long,
    help: """
          The name of the project, if it's different from the current working directory's name.
          If this option is set, carton will create the package for the project in a subdirectory by the given name.
          Otherwise, the package will be created in the current working directory, with the package named after the directory's.
          """
  )
  var name: String?

  func run() throws {
    let terminal = InteractiveWriter.stdout

    guard let currentDirectory = localFileSystem.currentWorkingDirectory else {
      throw ProjectInitialisationError.cannotFindCurrentDirectory
    }

    /// The kind of template the project is to be created with.
    /// - Note: This value is of the type `Templates`, not `Template`.
    let template = self.template ?? .basic

    let projectName = name ?? currentDirectory.basename
    let projectPath = name == nil ? currentDirectory : currentDirectory.appending(component: projectName)
    
    // FIXME: Replace with `NSString.abbreviatingWithTildeInPath`?
    let packagePathRelativeToHomeDirectory = projectPath.relative(to: localFileSystem.homeDirectory)

    terminal.write("Creating new project with template ")
    terminal.write("\(template.rawValue)", inColor: .green)
    terminal.write(" in ")
    terminal.write("~/\(packagePathRelativeToHomeDirectory.pathString)\n", inColor: .cyan)

    do {
      // `LocalFileSystem.createDirectory` wraps `FileManager.createDirectory`, which throws an NSError.
      try localFileSystem.createDirectory(projectPath)
    } catch let nsError as NSError {
        throw ProjectInitialisationError.cannotCreateDirectory(path: packagePathRelativeToHomeDirectory, reason: nsError.localizedDescription)
    }
    
    // FIXME: Handle this error-catching in each `Template.create()` instead.
    do {
      // FIXME:  The first `template` is of type `Templates`, and two consecutive `template` looks odd.
      // Maybe rename `Templates` as `TemplateKind`, and refactor `Template` so the template doesn't have to be created this way.
      try template.template.createProject(
        at: projectPath,
        inSubdirectory: name != nil,
        on: localFileSystem,
        terminal: terminal
      )
    } catch let nsError as NSError {
        throw ProjectInitialisationError.cannotCreateWithTemplate(template, reason: nsError.localizedDescription)
    } catch let error {
        throw ProjectInitialisationError.cannotCreateWithTemplate(template, reason: "\(error)")
    }
  }
}

// TODO: Add a diagnostics engine for errors thrown.

enum ProjectInitialisationError: Error, CustomStringConvertible {
    case cannotFindCurrentDirectory
    case cannotCreateDirectory(path: RelativePath, reason: String)
    case cannotCreateWithTemplate(Templates, reason: String)
    
    var description: String {
        switch self {
        case .cannotFindCurrentDirectory:
            return "Cannot find the current working directory."
        case let .cannotCreateDirectory(path, reason):
            return "Cannot create directory ~/\(path.pathString): \(reason)"
        case let .cannotCreateWithTemplate(template, reason):
            return "Cannot create project with template '\(template)': \(reason)"
        }
    }
}
