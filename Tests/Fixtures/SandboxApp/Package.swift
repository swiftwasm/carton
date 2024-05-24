// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "DevServerTestApp",
  products: [
    .executable(name: "app", targets: ["app"])
  ],
  dependencies: [
    .package(path: "../../.."),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.19.2")
  ],
  targets: [
    .executableTarget(
      name: "app",
      dependencies: [
        .product(name: "JavaScriptKit", package: "JavaScriptKit")
      ],
      resources: [
        .copy("style.css")
      ]
    ),
    .testTarget(
        name: "SimpleTests"
    )
  ]
)
