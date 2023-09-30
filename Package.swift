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
      revision: "fc510a39cff61b849bf5cdff17eb2bd6d0777b49"
    ),
    .package(url: "https://github.com/vapor/async-kit.git",
             revision: "c3329e444bafbb12d1d312af9191be95348a8175"),
    .package(url: "https://github.com/vapor/console-kit.git",
             revision: "a7e67a1719933318b5ab7eaaed355cde020465b1"),
    .package(url: "https://github.com/vapor/multipart-kit.git",
             revision: "0d55c35e788451ee27222783c7d363cb88092fab"),
    .package(url: "https://github.com/vapor/routing-kit.git",
             revision: "ffac7b3a127ce1e85fb232f1a6271164628809ad"),
    .package(url: "https://github.com/JohnSundell/Splash.git",
             revision: "7f4df436eb78fe64fe2c32c58006e9949fa28ad8"),
    .package(url: "https://github.com/apple/swift-algorithms.git",
             revision: "b14b7f4c528c942f121c8b860b9410b2bf57825e"),
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      revision: "e394bf350e38cb100b6bc4172834770ede1b7232"
    ),
    .package(url: "https://github.com/apple/swift-atomics.git",
             revision: "919eb1d83e02121cdb434c7bfc1f0c66ef17febe"),
    .package(url: "https://github.com/swift-server/swift-backtrace.git",
             revision: "80746bdd0ac8a7d83aad5d89dac3cbf15de652e6"),
    .package(url: "https://github.com/apple/swift-collections.git",
             revision: "937e904258d22af6e447a0b72c0bc67583ef64a2"),
    .package(url: "https://github.com/apple/swift-crypto.git",
             revision: "75ec60b8b4cc0f085c3ac414f3dca5625fa3588e"),
    .package(url: "https://github.com/apple/swift-driver.git",
             revision: "release/5.8"),
    .package(url: "https://github.com/apple/swift-llbuild.git",
             revision: "release/5.8"),
    .package(url: "https://github.com/apple/swift-log.git",
             revision: "532d8b529501fb73a2455b179e0bbb6d49b652ed"),
    .package(url: "https://github.com/apple/swift-metrics.git",
             revision: "971ba26378ab69c43737ee7ba967a896cb74c0d1"),
    .package(url: "https://github.com/apple/swift-nio.git",
             revision: "b4e0a274f7f34210e97e2f2c50ab02a10b549250"),
    .package(url: "https://github.com/apple/swift-nio-extras.git",
             revision: "fb70a0f5e984f23be48b11b4f1909f3bee016178"),
    .package(url: "https://github.com/apple/swift-nio-http2.git",
             revision: "a8ccf13fa62775277a5d56844878c828bbb3be1a"),
    .package(url: "https://github.com/apple/swift-nio-ssl.git",
             revision: "320bd978cceb8e88c125dcbb774943a92f6286e9"),
    .package(url: "https://github.com/apple/swift-nio-transport-services.git",
             revision: "e7403c35ca6bb539a7ca353b91cc2d8ec0362d58"),
    .package(url: "https://github.com/apple/swift-numerics",
             revision: "0a5bc04095a675662cf24757cc0640aa2204253b"),
    .package(
      name: "SwiftPM",
      url: "https://github.com/apple/swift-package-manager.git",
      revision: "85426bdaa5a455854a1c63cae7d5e73955b57628"
    ),
    .package(url: "https://github.com/apple/swift-system.git",
             revision: "836bc4557b74fe6d2660218d56e3ce96aff76574"),
    .package(
        url: "https://github.com/apple/swift-tools-support-core.git",
        revision: "release/5.8"
    ),
    .package(url: "https://github.com/vapor/vapor.git",
             revision: "971becba16d6faf5c4cb869d2e3026e822d09059"),
    .package(
      url: "https://github.com/swiftwasm/WasmTransformer",
      revision: "d04b31f61b6f528a9a96ebfe4fa4275e333eba82"
    ),
    .package(url: "https://github.com/jpsim/Yams.git",
             revision: "0d9ee7ea8c4ebd4a489ad7a73d5c6cad55d6fed3"),
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
        .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
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
