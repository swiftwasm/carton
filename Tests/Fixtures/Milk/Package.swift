// swift-tools-version:5.3
import PackageDescription
let package = Package(
  name: "Milk",
  platforms: [.macOS(.v11)],
  products: [
    .executable(name: "Milk", targets: ["Milk"]),
  ],
  dependencies: [
    .package(name: "Tokamak", url: "https://github.com/TokamakUI/Tokamak", .branch("maxd/update-jskit")),
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
