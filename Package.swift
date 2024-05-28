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
    .library(name: "CartonDriver", targets: ["CartonDriver"]),
    .library(name: "CartonKit", targets: ["CartonKit"]),
    .library(name: "CartonFrontend", targets: ["CartonFrontend"]),
    .executable(name: "carton", targets: ["carton"]),
    .executable(name: "carton-release", targets: ["carton-release"]),
    .plugin(name: "CartonBundlePlugin", targets: ["CartonBundlePlugin"]),
    .plugin(name: "CartonTestPlugin", targets: ["CartonTestPlugin"]),
    .plugin(name: "CartonDevPlugin", targets: ["CartonDevPlugin"]),
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
    .target(
      name: "CartonDriver",
      dependencies: [
        "SwiftToolchain",
        "CartonHelpers"
      ]
    ),
    .executableTarget(
      name: "carton",
      dependencies: [
        "CartonDriver"
      ]
    ),
    .executableTarget(
      name: "carton-frontend",
      dependencies: [
        "CartonFrontend"
      ]
    ),
    .plugin(
        name: "CartonBundlePlugin",
        capability: .command(
            intent: .custom(
                verb: "carton-bundle",
                description: "Produces an optimized app bundle for distribution."
            )
        ),
        dependencies: ["carton-frontend"],
        exclude: [
          "CartonCore/README.md",
          "CartonPluginShared/README.md"
        ]
    ),
    .plugin(
        name: "CartonTestPlugin",
        capability: .command(
            intent: .custom(
                verb: "carton-test",
                description: "Run the tests in a WASI environment."
            )
        ),
        dependencies: ["carton-frontend"],
        exclude: [
          "CartonCore/README.md",
          "CartonPluginShared/README.md"
        ]
    ),
    .plugin(
        name: "CartonDevPlugin",
        capability: .command(
            intent: .custom(
                verb: "carton-dev",
                description: "Watch the current directory, host the app, rebuild on change."
            )
        ),
        dependencies: ["carton-frontend"],
        exclude: [
          "CartonCore/README.md",
          "CartonPluginShared/README.md"
        ]
    ),
    .executableTarget(name: "carton-plugin-helper"),
    .target(
      name: "CartonFrontend",
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
        "WebDriver",
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
      /** Shim target to import missing C headers in Darwin and Glibc modulemap. */
      name: "TSCclibc",
      cSettings: [
        .define("_GNU_SOURCE", .when(platforms: [.linux])),
      ]
    ),
    .target(
        /** Cross-platform access to bare `libc` functionality. */
        name: "TSCLibc"
    ),
    .target(
      name: "CartonHelpers",
      dependencies: [
        "TSCclibc",
        "TSCLibc",
        "CartonCore"
      ],
      exclude: ["Basics/README.md"]
    ),
    .target(
      name: "CartonCore",
      exclude: ["README.md"]
    ),
    .target(
      name: "WebDriver",
      dependencies: [
        .product(name: "NIO", package: "swift-nio"),
        "CartonHelpers"
      ]
    ),
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
        "CartonFrontend",
        "SwiftToolchain",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(name: "WebDriverTests", dependencies: ["WebDriver"]),
  ]
)
