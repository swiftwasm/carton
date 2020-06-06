// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "carton",
  platforms: [.macOS(.v10_15)],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.1.0")),
    .package(url: "https://github.com/apple/swift-tools-support-core.git", .upToNextMinor(from: "0.1.3")),
    .package(url: "https://github.com/broadwaylamb/OpenCombine.git", .upToNextMinor(from: "0.8.0")),
    .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.3.0"),
    .package(url: "https://github.com/NSHipster/HypertextLiteral", .upToNextMinor(from: "0.0.1")),
    .package(url: "https://github.com/vapor/vapor.git", from: "4.5.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(
      name: "carton",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Vapor", package: "vapor"),
        .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        "HypertextLiteral",
        "OpenCombine",
        "ShellOut",
      ]
    ),
    .testTarget(
      name: "CartonTests",
      dependencies: ["carton"]
    ),
  ]
)
