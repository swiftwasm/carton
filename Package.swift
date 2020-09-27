// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let openCombineProduct = Target.Dependency.product(
  name: "OpenCombine",
  package: "OpenCombine",
  condition: .when(platforms: [.linux])
)

let package = Package(
  name: "carton",
  platforms: [.macOS(.v10_15)],
  dependencies: [
    .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.1.1"),
    .package(
      url: "https://github.com/apple/swift-argument-parser",
      .upToNextMinor(from: "0.3.0")
    ),
    .package(
      url: "https://github.com/apple/swift-tools-support-core.git",
      .upToNextMinor(from: "0.1.10")
    ),
    .package(url: "https://github.com/OpenCombine/OpenCombine.git", from: "0.10.0"),
    .package(url: "https://github.com/vapor/vapor.git", from: "4.29.3"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "1.1.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module
    // or a test suite. Targets can depend on other targets in this package, and on
    // products in packages which this package depends on.
    .target(
      name: "carton",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "Crypto", package: "swift-crypto"),
        .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        .product(name: "Vapor", package: "vapor"),
        "CartonHelpers",
        openCombineProduct,
        "SwiftToolchain",
      ]
    ),
    .target(
      name: "SwiftToolchain",
      dependencies: [
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        "CartonHelpers",
        openCombineProduct,
      ]
    ),
    .target(
      name: "CartonHelpers",
      dependencies: [
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        openCombineProduct,
      ]
    ),
    // This target is used only for release automation tasks and
    // should not be installed by `carton` users.
    .target(
      name: "carton-release",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        "CartonHelpers",
      ]
    ),
    .testTarget(
      name: "CartonTests",
      dependencies: ["carton"]
    ),
  ]
)
