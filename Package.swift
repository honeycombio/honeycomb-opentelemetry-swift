// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "honeycomb-opentelemetry-swift",
    platforms: [
        .macOS(.v12),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "Honeycomb", type: .static, targets: ["Honeycomb"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift-core.git",
            exact: "2.2.0"
        ),
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift.git",
            exact: "2.1.0"
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Honeycomb",
            dependencies: [
                .product(name: "BaggagePropagationProcessor", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
                .product(name: "OpenTelemetryProtocolExporter", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
                .product(name: "PersistenceExporter", package: "opentelemetry-swift"),
                .product(name: "StdoutExporter", package: "opentelemetry-swift-core"),
            ]
        ),
        .testTarget(
            name: "HoneycombTests",
            dependencies: [
                "Honeycomb",
                .product(name: "InMemoryExporter", package: "opentelemetry-swift"),
            ],
            path: "Tests/Honeycomb"
        ),
    ]
)
.addPlatformSpecific()

extension Package {
    func addPlatformSpecific() -> Self {
        #if canImport(Darwin)
            targets[0].dependencies
                .append(.product(name: "NetworkStatus", package: "opentelemetry-swift"))
            targets[0].dependencies
                .append(.product(name: "ResourceExtension", package: "opentelemetry-swift"))
        #endif
        return self
    }
}
