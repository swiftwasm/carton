// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CartonTestApp",
  products: [
    .executable(name: "TestApp", targets: ["TestApp"]),
  ],
  dependencies: [
    .package(url: "https://github.com/kateinoigakukun/JavaScriptKit", .revision("85b8617")),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(name: "TestApp", dependencies: ["JavaScriptKit", "TestLibrary"]),
    .target(name: "TestLibrary"),
    .testTarget(name: "Tests", dependencies: ["TestLibrary"]),
  ]
)
