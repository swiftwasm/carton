// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CartonPlugin",
  platforms: [.macOS("10.15.4")],
  products: [
    .plugin(name: "WebAssemblyBuildSupport", targets: ["WebAssemblyBuildSupport"]),
  ],
  dependencies: [
  ],
  targets: [
    .plugin(
      name: "WebAssemblyBuildSupport",
      capability: .command(
        intent: .custom(verb: "build-wasm", description: "Build .wasm")
      )
    ),
  ]
)
