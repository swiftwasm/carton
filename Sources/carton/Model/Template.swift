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

import SwiftToolchain
import TSCBasic

enum Templates: String, CaseIterable {
  case basic
  case tokamak

  var template: Template.Type {
    switch self {
    case .basic: return Basic.self
    case .tokamak: return Tokamak.self
    }
  }
}

protocol Template {
  static var description: String { get }
  static func create(on fileSystem: FileSystem,
                     project: Project,
                     _ terminal: TerminalController) throws
}

enum TemplateError: Error {
  case notImplemented
}

struct PackageDependency: CustomStringConvertible {
  let name: String
  let url: String
  let version: Version

  enum Version: CustomStringConvertible {
    case from(String)
    case branch(String)
    var description: String {
      switch self {
      case let .from(min):
        return #"from: "\#(min)""#
      case let .branch(branch):
        return #".branch("\#(branch)")"#
      }
    }
  }

  var description: String {
    #".package(name: "\#(name)", url: "\#(url)", \#(version))"#
  }
}

struct TargetDependency: CustomStringConvertible {
  let name: String
  let package: String
  var description: String {
    #".product(name: "\#(name)", package: "\#(package)")"#
  }
}

extension Template {
  static func createPackage(type: PackageType,
                            fileSystem: FileSystem,
                            project: Project,
                            _ terminal: TerminalController) throws {
    try Toolchain(fileSystem, terminal)
      .packageInit(name: project.name, type: type, inPlace: project.inPlace)
  }

  static func createManifest(fileSystem: FileSystem,
                             project: Project,
                             dependencies: [PackageDependency] = [],
                             targetDepencencies: [TargetDependency] = [],
                             _ terminal: TerminalController) throws {
    try fileSystem.writeFileContents(project.path.appending(component: "Package.swift")) {
      """
      // swift-tools-version:5.3
      import PackageDescription
      let package = Package(
          name: "\(project.name)",
          platforms: [.macOS(.v10_15)],
          products: [
              .executable(name: "\(project.name)", targets: ["\(project.name)"])
          ],
          dependencies: [
              \(dependencies.map(\.description).joined(separator: ",\n"))
          ],
          targets: [
              .target(
                  name: "HelloWorld",
                  dependencies: [
                      \(targetDepencencies.map(\.description).joined(separator: ",\n"))
                  ]),
              .testTarget(
                  name: "\(project.name)Tests",
                  dependencies: ["\(project.name)"]),
          ]
      )
      """
      .write(to: $0)
    }
  }
}

// MARK: Templates

extension Templates {
  struct Basic: Template {
    static let description: String = "A simple SwiftWasm project."

    static func create(on fileSystem: FileSystem,
                       project: Project,
                       _ terminal: TerminalController) throws {
      try fileSystem.changeCurrentWorkingDirectory(to: project.path)
      try createPackage(type: .executable,
                        fileSystem: fileSystem,
                        project: project,
                        terminal)
      try createManifest(fileSystem: fileSystem,
                         project: project,
                         terminal)
    }
  }
}

extension Templates {
  struct Tokamak: Template {
    static let description: String = "A simple Tokamak project."

    static func create(on fileSystem: FileSystem,
                       project: Project,
                       _ terminal: TerminalController) throws {
      try fileSystem.changeCurrentWorkingDirectory(to: project.path)
      try createPackage(type: .executable,
                        fileSystem: fileSystem,
                        project: project,
                        terminal)
      try createManifest(fileSystem: fileSystem,
                         project: project,
                         dependencies: [
                           .init(name: "Tokamak", url: "https://github.com/swiftwasm/Tokamak", version: .branch("main")),
                         ],
                         targetDepencencies: [
                           .init(name: "TokamakDOM", package: "Tokamak"),
                         ],
                         terminal)
      try fileSystem.writeFileContents(project.path.appending(components: "Sources", project.name, "main.swift")) {
        """
        import TokamakDOM
        import JavaScriptKit

        let document = JSObjectRef.global.document.object!
        let body = document.body.object!
        body.style = "margin: 0;"

        let div = document.createElement!("div").object!
        let renderer = DOMRenderer(ContentView(), div)
        _ = body.appendChild!(div)
        """
        .write(to: $0)
      }
      try fileSystem.writeFileContents(project.path.appending(components: "Sources", project.name, "ContentView.swift")) {
        """
        import TokamakDOM

        struct ContentView: View {
            var body: some View {
                Text("Hello, world!")
            }
        }
        """
        .write(to: $0)
      }
    }
  }
}
