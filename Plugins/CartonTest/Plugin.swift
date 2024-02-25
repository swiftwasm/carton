// Copyright 2024 Carton contributors
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

import Foundation
import PackagePlugin

@main
struct CartonTestPlugin: CommandPlugin {
  struct Options {
    var environment: Environment
    var prebuiltTestBundlePath: String?

    static func parse(from extractor: inout ArgumentExtractor) throws -> Options {
      let environment = try Environment.parse(from: &extractor)
      let prebuiltTestBundlePath = extractor.extractOption(named: "prebuilt-test-bundle-path").first
      return Options(environment: environment, prebuiltTestBundlePath: prebuiltTestBundlePath)
    }
  }

  typealias Error = CartonPluginError

  func performCommand(context: PluginContext, arguments: [String]) async throws {
    try checkSwiftVersion()
    try checkHelpFlag(arguments, subcommand: "test", context: context)

    let productName = "\(context.package.displayName)PackageTests"

    if arguments.first == "internal-get-build-command" {
      var extractor = ArgumentExtractor(Array(arguments.dropFirst()))
      let options = try Options.parse(from: &extractor)
      var buildCommand: [String] = []
      if options.prebuiltTestBundlePath == nil {
        var buildParameters = Environment.Parameters()
        options.environment.applyBuildParameters(&buildParameters)
        buildCommand = ["build", "--product", productName]
        buildCommand += buildParameters.otherSwiftcFlags.flatMap { ["-Xswiftc", $0] }
        buildCommand += buildParameters.otherLinkerFlags.flatMap { ["-Xlinker", $0] }
      }

      let outputFile = extractor.extractOption(named: "output").last!
      try buildCommand.joined(separator: "\n").write(
        toFile: outputFile, atomically: true, encoding: .utf8)
      return
    }

    var extractor = ArgumentExtractor(arguments)
    let options = try Options.parse(from: &extractor)
    let buildDirectory = try self.buildDirectory(context: context)

    let testProductArtifactPath = try options.prebuiltTestBundlePath ?? {
      let wasmFileName = "\(productName).wasm"
      let testProductArtifactPath = buildDirectory.appending(subpath: wasmFileName).string
      // TODO: SwiftPM does not allow to build *only tests* from plugin
      guard FileManager.default.fileExists(atPath: testProductArtifactPath) else {
        throw Error(
          "Failed to find \"\(wasmFileName)\" in \(buildDirectory). Please build \"\(productName)\" product first"
        )
      }
      return testProductArtifactPath
    }()

    let testTargets = context.package.targets(ofType: SwiftSourceModuleTarget.self).filter {
      $0.kind == .test
    }

    let resourcesPaths = deriveResourcesPaths(
      buildDirectory: buildDirectory,
      sourceTargets: testTargets,
      package: context.package
    )

    let frontendArguments =
      [
        "test",
        "--prebuilt-test-bundle-path", testProductArtifactPath,
        "--environment", options.environment.rawValue,
      ]
      + resourcesPaths.flatMap {
        ["--resources", $0.string]
      } + extractor.remainingArguments
    let frontend = try makeCartonFrontendProcess(context: context, arguments: frontendArguments)
    frontend.forwardTerminationSignals()
    try frontend.run()
    frontend.waitUntilExit()
    frontend.checkNonZeroExit()
  }

  private func defaultProduct(context: PluginContext) throws -> String {
    let executableProducts = context.package.products(ofType: ExecutableProduct.self)
    guard !executableProducts.isEmpty else {
      throw Error("Make sure there's at least one executable product in your Package.swift")
    }
    guard executableProducts.count == 1 else {
      throw Error(
        "Failed to disambiguate the product. Pass one of \(executableProducts.map(\.name).joined(separator: ", ")) to the --product option"
      )

    }
    return executableProducts[0].name
  }

  private func buildDirectory(context: PluginContext) throws -> Path {
    let build = try packageManager.build(
      .product("carton-plugin-helper"), parameters: PackageManager.BuildParameters())
    guard build.succeeded else {
      throw Error("Failed to build carton-plugin-helper: \(build.logText)")
    }
    guard !build.builtArtifacts.isEmpty else {
      throw Error("No built artifacts found for carton-plugin-helper")
    }
    guard build.builtArtifacts.count == 1 else {
      throw Error(
        "Multiple built artifacts found for carton-plugin-helper!?: \(build.builtArtifacts.map(\.path.string).joined(separator: ", "))"
      )
    }
    return build.builtArtifacts[0].path.removingLastComponent()
  }
}
