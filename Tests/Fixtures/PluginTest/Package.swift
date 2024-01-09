// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PluginTest",
  dependencies: [
    .package(path: "../../../"),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.19.0"),
  ],
  targets: [
    .executableTarget(name: "PluginTestExe", dependencies: ["JavaScriptKit"]),
    .target(name: "PluginTest"),
    .testTarget(name: "PluginTestTests", dependencies: ["PluginTest"]),
  ]
)
