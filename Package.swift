// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "honeycomb-opentelemetry-swift",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v12),
        .tvOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "Honeycomb", type: .static, targets: ["Honeycomb"]),
    ],
    dependencies: [
        // This revision is needed for now to avoid unsafe flags.
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift.git", from:"1.10.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Honeycomb",
            dependencies: [
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporter", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
            ]),
        .testTarget(
            name: "HoneycombTests",
            dependencies: ["Honeycomb"]),
    ]
)
