# Honeycomb OpenTelemetry Swift

[![OSS Lifecycle](https://img.shields.io/osslifecycle/honeycombio/honeycomb-opentelemetry-swift)](https://github.com/honeycombio/home/blob/main/honeycomb-oss-lifecycle-and-practices.md)
[![CircleCI](https://circleci.com/gh/honeycombio/honeycomb-opentelemetry-swift.svg?style=shield)](https://circleci.com/gh/honeycombio/honeycomb-opentelemetry-swift)

Honeycomb wrapper for [OpenTelemetry](https://opentelemetry.io) on iOS and macOS.

**STATUS: this library is EXPERIMENTAL.** Data shapes are unstable and not safe for production. We are actively seeking feedback to ensure usability.

## Getting started

### Xcode

If you're using Xcode to manage dependencies...

  1. Select "Add Package Dependencies..." from the "File" menu.
  2. In the search field in the upper right, labeled “Search or Enter Package URL”, enter the Swift
     Honeycomb OpenTelemetry package url: https://github.com/honeycombio/honeycomb-opentelemetry-swift
  3. Add a project dependency on `Honeycomb`.

### Package.swift

If you're using `Package.swift` to manage dependencies...

1. Add the Package dependency.

```swift
    dependencies: [
        .package(url: "https://github.com/honeycombio/honeycomb-opentelemetry-swift.git",
                 from: "0.0.1-alpha")
    ],
```

2. Add the target dependency.

```swift
    dependencies: [
        .product(name: "Honeycomb", package: "honeycomb-opentelemetry-swift"),
    ],
```

### Initializing the SDK

To configure the SDK in your `App` class:
```swift
import Honeycomb

@main
struct ExampleApp: App {
    init() {
        do {
            let options = try HoneycombOptions.Builder()
                .setAPIKey("YOUR-API-KEY")
                .setServiceName("YOUR-SERVICE-NAME")
                .build()
            try Honeycomb.configure(options: options)
        } catch {
            NSException(name: NSExceptionName("HoneycombOptionsError"), reason: "\(error)").raise()
        }
    }
}
```

To manually send a span:
```swift
    let tracerProvider = OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: "YOUR-INSTRUMENTATION-NAME",
        instrumentationVersion: nil
    )
    let span = tracerProvider.spanBuilder(spanName: "YOUR-SPAN-NAME").startSpan()
    span.end()
```

## Auto-instrumentation

The following auto-instrumentation libraries are automatically included:
* [MetricKit](https://developer.apple.com/documentation/metrickit) data is automatically collected.
