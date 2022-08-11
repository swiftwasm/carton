// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "carton",
  platforms: [.macOS("10.15.4")],
  products: [
    .library(name: "SwiftToolchain", targets: ["SwiftToolchain"]),
    .library(name: "CartonHelpers", targets: ["CartonHelpers"]),
    .library(name: "CartonKit", targets: ["CartonKit"]),
    .library(name: "CartonCLI", targets: ["CartonCLI"]),
    .executable(name: "carton", targets: ["Carton"]),
    .executable(name: "carton-release", targets: ["carton-release"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/swift-server/async-http-client.git",
      from: "1.8.1"
    ),
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      .upToNextMinor(from: "1.0.3")
    ),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.34.0"),
    .package(
      name: "SwiftPM",
      url: "https://github.com/apple/swift-package-manager.git",
      .branch("release/5.7")
    ),
    .package(
      url: "https://github.com/apple/swift-tools-support-core.git",
      .branch("release/5.7")
    ),
    .package(url: "https://github.com/vapor/vapor.git", from: "4.57.1"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "1.1.0"),
    .package(url: "https://github.com/apple/swift-system.git", from: "1.1.1"),
    .package(url: "https://github.com/JohnSundell/Splash.git", from: "0.16.0"),
    .package(
      url: "https://github.com/swiftwasm/WasmTransformer",
      .upToNextMinor(from: "0.3.0")
    ),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module
    // or a test suite. Targets can depend on other targets in this package, and on
    // products in packages which this package depends on.
    .executableTarget(
      name: "Carton",
      dependencies: [
        "CartonCLI",
      ]
    ),
    .target(
      name: "CartonCLI",
      dependencies: ["CartonKit"]
    ),
    .target(
      name: "CartonKit",
      dependencies: [
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "Crypto", package: "swift-crypto"),
        .product(name: "Vapor", package: "vapor"),
        .product(name: "CSystem", package: "swift-system", condition: .when(platforms: [.linux])),
        "CartonHelpers",
        "SwiftToolchain",
        "WebDriverClient",
      ]
    ),
    .target(
      name: "SwiftToolchain",
      dependencies: [
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "NIOFoundationCompat", package: "swift-nio"),
        .product(name: "SwiftPMDataModel-auto", package: "SwiftPM"),
        "CartonHelpers",
        "WasmTransformer",
      ]
    ),
    .target(
      name: "CartonHelpers",
      dependencies: [
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "Splash",
        "WasmTransformer",
      ]
    ),
    .target(name: "WebDriverClient", dependencies: [
      .product(name: "AsyncHTTPClient", package: "async-http-client"),
      .product(name: "NIOFoundationCompat", package: "swift-nio"),
    ]),
    // This target is used only for release automation tasks and
    // should not be installed by `carton` users.
    .executableTarget(
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
      dependencies: [
        "Carton",
        "CartonHelpers",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(
      name: "CartonCommandTests",
      dependencies: [
        "CartonCLI",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "TSCTestSupport", package: "swift-tools-support-core"),
      ]
    ),
    .testTarget(name: "WebDriverClientTests", dependencies: ["WebDriverClient"]),
  ]
)
