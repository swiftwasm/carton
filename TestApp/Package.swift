// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CartonTestApp",
  dependencies: [
    .package(url: "https://github.com/kateinoigakukun/JavaScriptKit", .revision("b245ad5")),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(name: "TestApp", dependencies: ["JavaScriptKit", "TestLibrary"]),
    .target(name: "TestLibrary"),
    .testTarget(name: "Tests", dependencies: ["TestLibrary"]),
  ]
)
