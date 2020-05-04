// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "carton",
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.0.5")),
    .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.11.0"),
    .package(url: "https://github.com/MaxDesiatov/SKQueue.git", .branch("master")),
    .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.1.1"),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(
      name: "carton",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "NIOHTTP2Server", package: "swift-nio-http2"),
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "SKQueue", package: "SKQueue"),
      ]
    ),
    .testTarget(
      name: "CartonTests",
      dependencies: ["carton"]
    ),
  ]
)
