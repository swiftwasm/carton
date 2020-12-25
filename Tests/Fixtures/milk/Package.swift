// swift-tools-version:5.3
import PackageDescription
let package = Package(
  name: "milk",
  platforms: [.macOS(.v11)],
  products: [
    .executable(name: "milk", targets: ["Milk"]),
  ],
  dependencies: [
    .package(name: "Tokamak", url: "https://github.com/TokamakUI/Tokamak", from: "0.6.1"),
  ],
  targets: [
    .target(
      name: "Milk",
      dependencies: [
        .product(name: "TokamakShim", package: "Tokamak"),
      ]
    ),
    .testTarget(
      name: "MilkTests",
      dependencies: ["Milk"]
    ),
  ]
)
