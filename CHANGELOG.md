Honeycomb OpenTelemetry SDK Changelog

## v.Next

## 0.0.12

### New Features

* Add optional `severity` parameter to manual error-logging APIs.
* Add new resource attributes with build and version information.

### Fixes

* Change logging of `NSError` and Swift `Error` to match semantic conventions for _errors_, not _exceptions_.

## 0.0.11

### New Features

* `metrickit.diagnostic.crash` and `metrickit.diagnostic.hang` traces now include `stacktrace_json` attributes containing the raw (unsymbolicated) stacktrace supplied by the OS.
* Include semantic convention attributes for distro name and version.

## 0.0.10

### New Features

* Update to OpenTelemetry Swift 1.15.0.

## 0.0.9

### New Features

* Add `Honeycomb.currentSession()` method for getting the session ID.

## 0.0.8

### New Features

* Make API key optional when using a custom endpoint.

### Fixes

* NavigationStack root paths now get serialized as `/` instead of `[]`, even when using NavigationPath.
* Ensure navigation instrumention passes `prefix` param correctly.

## 0.0.7

### New Features

* Enhanced navigation instrumentation:
  * Now emits paired `NavigationTo` and `NavigationFrom` spans for better visibility into screen transitions and time spent on screens.
  * Now accepts optional `reason: String` param for tagging navigations.
  * Now accepts optional `prefix: String` param to allow clients to disambiguate between different NavigationStacks within a singular application.
  * Fix: NavigationStack root paths now get serialized as `/` instead of `[]`.
  * Fix: Navigation instrumentation now correctly identifies the `screen.name` attribute for paths, instead of using the full path.

### Fixes

* Wait for flush to avoid missed crash logs
* Add [UIDevice](https://developer.apple.com/documentation/uikit/uidevice) attributes to spans

## 0.0.6

### New Features

* Error logging API for manually logging exceptions.
* Add new options to enable/disable built-in auto-instrumentation.
* Uncaught exception handler to log crashes.
* Enable telemetry caching for offline support.
* Add network connection type attributes.
* Documentation added for propagating traces.
* feat: Add `setServiceVersion()` function to `HoneycombOptions` to allow clients to supply current application version.

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
