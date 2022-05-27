// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "IntegrationTests",
    targets: [
        .testTarget(
            name: "IntegrationTestsTests",
            path: "Tests",
            resources: [.copy("Fixtures")]),
    ]
)
