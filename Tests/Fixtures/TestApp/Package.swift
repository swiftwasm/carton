// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CartonTestApp",
  products: [
    .executable(name: "TestApp", targets: ["TestApp"]),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.15.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test
    // suite. Targets can depend on other targets in this package, and on products in packages which
    // this package depends on.
    .target(
      name: "TestApp",
      dependencies: ["JavaScriptKit", "TestLibrary", "CustomPathTarget"],
      resources: [.copy("data.json")]
    ),
    .target(name: "TestLibrary"),
    .target(name: "CustomPathTarget", path: "CustomPathTarget"),
    .testTarget(name: "Tests", dependencies: ["TestLibrary"]),
  ]
)
