// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if swift(<5.9.2)
#warning("Swift 5.9.1 or earlier is not supported by carton")
#endif

let package = Package(
  name: "carton",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "SwiftToolchain", targets: ["SwiftToolchain"]),
    .library(name: "CartonHelpers", targets: ["CartonHelpers"]),
    .library(name: "CartonKit", targets: ["CartonKit"]),
    .library(name: "CartonCLI", targets: ["CartonCLI"]),
    .executable(name: "carton", targets: ["carton"]),
    .executable(name: "carton-release", targets: ["carton-release"]),
    .plugin(name: "CartonBundle", targets: ["CartonBundle"]),
    .plugin(name: "CartonTest", targets: ["CartonTest"]),
    .plugin(name: "CartonDev", targets: ["CartonDev"]),
    .executable(name: "carton-plugin-helper", targets: ["carton-plugin-helper"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.4"),
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      .upToNextMinor(from: "1.3.0")
    ),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.34.0"),
    .package(
      url: "https://github.com/swiftwasm/WasmTransformer",
      .upToNextMinor(from: "0.5.0")
    ),
  ],
  targets: [
    .executableTarget(
      name: "carton",
      dependencies: [
        "SwiftToolchain",
        "CartonHelpers",
      ]
    ),
    .executableTarget(
      name: "CartonFrontend",
      dependencies: [
        "CartonCLI",
      ]
    ),
    .plugin(
        name: "CartonBundle",
        capability: .command(
            intent: .custom(
                verb: "carton-bundle",
                description: "Produces an optimized app bundle for distribution."
            )
        ),
        dependencies: ["CartonFrontend"],
        exclude: ["CartonPluginShared/README.md"]
    ),
    .plugin(
        name: "CartonTest",
        capability: .command(
            intent: .custom(
                verb: "carton-test",
                description: "Run the tests in a WASI environment."
            )
        ),
        dependencies: ["CartonFrontend"],
        exclude: ["CartonPluginShared/README.md"]
    ),
    .plugin(
        name: "CartonDev",
        capability: .command(
            intent: .custom(
                verb: "carton-dev",
                description: "Watch the current directory, host the app, rebuild on change."
            )
        ),
        dependencies: ["CartonFrontend"],
        exclude: ["CartonPluginShared/README.md"]
    ),
    .executableTarget(name: "carton-plugin-helper"),
    .target(
      name: "CartonCLI",
      dependencies: [
        .product(name: "Logging", package: "swift-log"),
        "CartonKit",
      ]
    ),
    .target(
      name: "CartonKit",
      dependencies: [
        .product(name: "NIOWebSocket", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "CartonHelpers",
        "WebDriverClient",
        "WasmTransformer",
      ],
      exclude: ["Utilities/README.md"]
    ),
    .target(
      name: "SwiftToolchain",
      dependencies: [
        "CartonHelpers",
      ],
      exclude: ["Utilities/README.md"]
    ),
    .target(
      name: "CartonHelpers",
      dependencies: [],
      exclude: ["Basics/README.md"]
    ),
    .target(name: "WebDriverClient", dependencies: []),
    // This target is used only for release automation tasks and
    // should not be installed by `carton` users.
    .executableTarget(
      name: "carton-release",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "CartonHelpers",
        "WasmTransformer",
      ]
    ),
    .testTarget(
      name: "CartonTests",
      dependencies: [
        "CartonFrontend",
        "CartonHelpers",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(
      name: "CartonCommandTests",
      dependencies: [
        "CartonCLI",
        "SwiftToolchain",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(name: "WebDriverClientTests", dependencies: ["WebDriverClient"]),
  ]
)
