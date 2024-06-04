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
struct CartonBundlePluginCommand: CommandPlugin {

  struct Options {
    var product: String?
    var outputDir: String?
    var debug: Bool

    static func parse(from extractor: inout ArgumentExtractor) -> Options {
      let product = extractor.extractOption(named: "product").last
      let outputDir = extractor.extractOption(named: "output").last
      let debug = extractor.extractFlag(named: "debug")
      return Options(product: product, outputDir: outputDir, debug: debug != 0)
    }
  }

  func performCommand(context: PluginContext, arguments: [String]) async throws {
    try checkSwiftVersion()
    try checkHelpFlag(arguments, subcommand: "bundle", context: context)

    var extractor = ArgumentExtractor(arguments)
    let options = Options.parse(from: &extractor)

    let productName = try options.product ?? deriveDefaultProduct(package: context.package)

    // Build products
    var parameters = PackageManager.BuildParameters(
      configuration: options.debug ? .debug : .release,
      logging: .verbose
    )
    #if compiler(>=5.11) || compiler(>=6)
    parameters.echoLogs = true
    parameters.logging = .concise
    #endif
    Environment.browser.applyBuildParameters(&parameters)
    applyExtraBuildFlags(from: &extractor, parameters: &parameters)

    print("Building \"\(productName)\"")
    let build = try self.packageManager.build(.product(productName), parameters: parameters)

    guard build.succeeded else {
      print(build.logText)
      exit(1)
    }

    guard let product = try context.package.products(named: [productName]).first else {
      throw CartonPluginError("Failed to find product named \"\(productName)\"")
    }
    guard let executableProduct = product as? ExecutableProduct else {
      throw CartonPluginError(
        "Product type of \"\(productName)\" is not supported. Only executable products are supported."
      )
    }

    let productArtifact = try build.findWasmArtifact(for: productName)

    let resourcesPaths = deriveResourcesPaths(
      productArtifactPath: productArtifact.path,
      sourceTargets: executableProduct.targets,
      package: context.package
    )

    let bundleDirectory =
      options.outputDir ?? context.pluginWorkDirectory.appending(subpath: "Bundle").string
    let frontendArguments =
      ["bundle", productArtifact.path.string, "--output", bundleDirectory]
      + resourcesPaths.flatMap {
        ["--resources", $0.string]
      } + extractor.remainingArguments
    let frontend = try makeCartonFrontendProcess(context: context, arguments: frontendArguments)
    try frontend.checkRun(printsLoadingMessage: false, forwardExit: true)
  }
}
