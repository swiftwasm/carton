// swift-tools-version:5.5
import PackageDescription

let package = Package(
  name: "Test",
  dependencies: [.package(path: "../../..")],
  targets: [.testTarget(name: "FailTest", path: "Tests")]
)
