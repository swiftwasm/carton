// swift-tools-version:5.5
import PackageDescription

let package = Package(
  name: "Test",
  targets: [.testTarget(name: "FailTest", path: "Tests")]
)
