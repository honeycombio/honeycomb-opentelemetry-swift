Honeycomb OpenTelemetry SDK Changelog

## v.Next

### New Features

* Add deterministic sampler (configurable through the `sampleRate` option)
* Emit session.id using default SessionManager
* Update to OpenTelemetry Swift 1.12.1.
* Auto-instrumentation of URLSession.
* Auto-instrumentation of navigation in UI Kit.
* Auto-instrumentation of "clicks" and touch events in UI Kit.
* Manual instrumentation of SwiftUI navigation.
* Manual instrumentation of SwiftUI view rendering.

## 0.0.1-alpha (2024-09-27)

Initial experimental release.

### New Features

* Easy configuration of OpenTelemetry SDK.
* Automatic MetricKit collection.
