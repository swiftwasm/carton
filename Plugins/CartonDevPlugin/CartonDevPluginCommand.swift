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
struct CartonDevPluginCommand: CommandPlugin {
  struct Options {
    var product: String?
    var release: Bool
    var verbose: Bool

    static func parse(from extractor: inout ArgumentExtractor) throws -> Options {
      let product = extractor.extractOption(named: "product").last
      let release = extractor.extractFlag(named: "release")
      let verbose = extractor.extractFlag(named: "verbose")
      return Options(product: product, release: release != 0, verbose: verbose != 0)
    }
  }

  typealias Error = CartonPluginError

  func performCommand(context: PluginContext, arguments: [String]) async throws {
    try checkSwiftVersion()
    try checkHelpFlag(arguments, subcommand: "dev", context: context)

    var extractor = ArgumentExtractor(arguments)
    let options = try Options.parse(from: &extractor)

    let productName = try options.product ?? self.defaultProduct(context: context)

    // Build products
    var parameters = PackageManager.BuildParameters(
      configuration: options.release ? .release : .debug,
      logging: options.verbose ? .verbose : .concise
    )
    #if compiler(>=5.11) || compiler(>=6)
    parameters.echoLogs = true
    #endif
    Environment.browser.applyBuildParameters(&parameters)
    applyExtraBuildFlags(from: &extractor, parameters: &parameters)

    print("Building \"\(productName)\"")
    let buildSubset = PackageManager.BuildSubset.product(productName)
    let build = try self.packageManager.build(buildSubset, parameters: parameters)
    guard build.succeeded else {
      print(build.logText)
      exit(1)
    }

    guard let product = try context.package.products(named: [productName]).first else {
      throw Error("Failed to find product named \"\(productName)\"")
    }
    guard let executableProduct = product as? ExecutableProduct else {
      throw Error(
        "Product type of \"\(productName)\" is not supported. Only executable products are supported."
      )
    }

    let productArtifact = try build.findWasmArtifact(for: productName)
    let pathsToWatch = context.package.targets.map { $0.directory.string }
    let resourcesPaths = deriveResourcesPaths(
      productArtifactPath: productArtifact.path,
      sourceTargets: executableProduct.targets,
      package: context.package
    )

    let tempDirectory = try createTemporaryDirectory(under: context.pluginWorkDirectory)
    defer { try? FileManager.default.removeItem(atPath: tempDirectory.string) }
    let buildRequestPipe = try createFifo(hint: "build-request", directory: tempDirectory)
    let buildResponsePipe = try createFifo(hint: "build-response", directory: tempDirectory)

    let frontend = try makeCartonFrontendProcess(
      context: context,
      arguments: [
        "dev",
        "--main-wasm-path", productArtifact.path.string,
        "--build-request", buildRequestPipe,
        "--build-response", buildResponsePipe,
      ]
        + resourcesPaths.flatMap { ["--resources", $0.string] }
        + pathsToWatch.flatMap { ["--watch-path", $0] }
        + (options.verbose ? ["--verbose"] : [])
        + extractor.remainingArguments
    )
    frontend.forwardTerminationSignals()

    try frontend.run()

    let buildRequestFileHandle = FileHandle(forReadingAtPath: buildRequestPipe)!
    let buildResponseFileHandle = FileHandle(forWritingAtPath: buildResponsePipe)!
    while let _ = try buildRequestFileHandle.read(upToCount: 1) {
      Diagnostics.remark("[Plugin] Received build request")
      let buildResult = try self.packageManager.build(buildSubset, parameters: parameters)
      if !buildResult.succeeded {
        Diagnostics.remark("[Plugin] **Build Failed**")
        print(buildResult.logText)
      } else {
        Diagnostics.remark("[Plugin] **Build Succeeded**")
      }
      try buildResponseFileHandle.write(contentsOf: Data([1]))
    }

    frontend.waitUntilExit()
    frontend.forwardExit()
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
}

private func createTemporaryDirectory(under directory: Path) throws -> Path {
  var template = directory.appending("carton-XXXXXX").string
  let result = try template.withUTF8 { template in
    let copy = UnsafeMutableBufferPointer<CChar>.allocate(capacity: template.count + 1)
    defer { copy.deallocate() }
    template.copyBytes(to: copy)
    copy[template.count] = 0
    guard let result = mkdtemp(copy.baseAddress!) else {
      throw CartonPluginError("Failed to create a temporary directory")
    }
    return String(cString: result)
  }
  return Path(result)
}

private func createFifo(hint: String, directory: Path) throws -> String {
  let fifoPath = directory.appending("\(hint).fifo").string
  guard mkfifo(fifoPath, 0o600) == 0 else {
    let error = String(cString: strerror(errno))
    throw CartonPluginError("Failed to create fifo at \(fifoPath): \(error)")
  }
  return fifoPath
}
