Honeycomb OpenTelemetry SDK Changelog

## v.Next

### New Features

* Error logging API for manually logging exceptions.
* Package is now available on Cocoapods.
* Add new options to enable/disable built-in auto-instrumentation.
* Uncaught exception handler to log crashes.
* Enable telemetry caching for offline support.

### Fixes

* Update instrumentation names to use reverse url notation (`io.honeycomb.*`) instead of `@honeycombio/instrumentation-*` notation. 
* Make session id management threadsafe.

## 0.0.5-alpha

### New Features

* Add a `setSpanProcessor()` function to `HoneycombOptions` builder to allow clients to supply custom span processors.

## 0.0.4-alpha

### Fixes

* Move `HoneycombSession` in `NotificationCenter` from being the sender to `userInfo`.

## 0.0.3-alpha (2025-02-11)

### New Features

* Update to OpenTelemetry Swift 1.12.1.
* Add deterministic sampler (configurable through the `sampleRate` option).
* Auto-instrumentation of navigation in UI Kit.
* Emit session.id using default SessionManager.
* Include `telemetry.sdk.language` and other default resource fields.

## 0.0.2-alpha (2024-12-20)

### New Features

* Update to OpenTelemetry Swift 1.10.1.
* Auto-instrumentation of URLSession.
* Auto-instrumentation of "clicks" and touch events in UI Kit.
* Manual instrumentation of SwiftUI navigation.
* Manual instrumentation of SwiftUI view rendering.
* Add baggage span processor.

## 0.0.1-alpha (2024-09-27)

Initial experimental release.

### New Features

* Easy configuration of OpenTelemetry SDK.
* Automatic MetricKit collection.
