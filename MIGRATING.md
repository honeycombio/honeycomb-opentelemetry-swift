# Migration Guide

## Migrating from 2.x to 3.0

Version 3.0 removes Honeycomb's custom URLSession and MetricKit instrumentation in favor of the upstream OpenTelemetry implementations.

### Breaking Changes

#### 1. Removed Configuration Options

The following options have been removed:
- `otelMetricKitInstrumentationEnabled` / `setOTELMetricKitInstrumentationEnabled()`
- `otelUrlSessionInstrumentationEnabled` / `setOTELURLSessionInstrumentationEnabled()`

The existing `metricKitInstrumentationEnabled` and `urlSessionInstrumentationEnabled` options now always use OpenTelemetry's implementations.

**Migration:** Remove the `setOTEL*` calls from your configuration:

```swift
// Before (2.x)
let options = try HoneycombOptions.Builder()
    .setOTELMetricKitInstrumentationEnabled(true)
    .setOTELURLSessionInstrumentationEnabled(true)
    .build()

// After (3.0) - remove the setOTEL* calls
let options = try HoneycombOptions.Builder()
    .build()
```

#### 2. MetricKit Telemetry Changes

**Instrumentation scope changed:**
- Old: `io.honeycomb.metrickit`
- New: `MetricKit`

**Update queries and dashboards:**
```
# Before
WHERE instrumentation.scope.name = "io.honeycomb.metrickit"

# After
WHERE instrumentation.scope.name = "MetricKit"
```

**Diagnostic stacktrace attribute changed:**
- Old: `metrickit.diagnostic.hang.exception.stacktrace_json`, `metrickit.diagnostic.crash.exception.stacktrace_json`
- New: `exception.stacktrace` (standard OTel attribute)

**Update stacktrace queries:**
```
# Before
WHERE metrickit.diagnostic.hang.exception.stacktrace_json EXISTS

# After
WHERE exception.stacktrace EXISTS AND name = "metrickit.diagnostic.hang"
```

Since multiple diagnostic types share `exception.stacktrace`, filter by `name`:
- Hang diagnostics: `name = "metrickit.diagnostic.hang"`
- Crash diagnostics: `name = "metrickit.diagnostic.crash"`

#### 3. URLSession Telemetry

No breaking changes. URLSession continues using the `io.honeycomb.urlsession` scope.

---

### Need Help?

[Open an issue](https://github.com/honeycombio/honeycomb-opentelemetry-swift/issues) if you encounter problems during migration.
