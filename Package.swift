// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "honeycomb-opentelemetry-swift",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "honeycomb-opentelemetry-swift",
            targets: ["honeycomb-opentelemetry-swift"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "honeycomb-opentelemetry-swift"),
        .testTarget(
            name: "honeycomb-opentelemetry-swiftTests",
            dependencies: ["honeycomb-opentelemetry-swift"]),
    ]
)
