// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "carton",
  platforms: [.macOS(.v10_15)],
  dependencies: [
    .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.1.1"),
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.1.0")),
    .package(url: "https://github.com/apple/swift-tools-support-core.git", .upToNextMinor(from: "0.1.3")),
    .package(url: "https://github.com/broadwaylamb/OpenCombine.git", .upToNextMinor(from: "0.9.0")),
    .package(url: "https://github.com/vapor/vapor.git", .upToNextMinor(from: "4.5.0")),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(
      name: "carton",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "Vapor", package: "vapor"),
        .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        "OpenCombine",
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
      ]
    ),
    .testTarget(
      name: "CartonTests",
      dependencies: ["carton"]
    ),
  ]
)
