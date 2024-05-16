// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "DevServerTestApp",
  products: [
    .executable(name: "app", targets: ["app"])
  ],
  dependencies: [
    .package(path: "../../..")
  ],
  targets: [
    .executableTarget(
      name: "app",
      resources: [
        .copy("style.css")
      ]
    )
  ]
)
