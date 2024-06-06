// swift-tools-version:5.5
import PackageDescription

let package = Package(
  name: "Foo",
  products: [.executable(name: "my-echo", targets: ["my-echo"])],
  dependencies: [.package(path: "../../..")],
  targets: [.executableTarget(name: "my-echo")]
)
