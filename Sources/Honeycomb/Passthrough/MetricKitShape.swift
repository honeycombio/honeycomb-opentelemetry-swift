import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// The scope that Honeycomb's own MetricKit subscriber has always used for both spans and logs.
let honeycombMetricKitScope = "io.honeycomb.metrickit"

private let diagnosticNamePrefix = "metrickit.diagnostic."

/// Upstream `MetricKitInstrumentation` produces the same `MXMetricPayload`, `MXSignpostMetric` and
/// `MXDiagnosticPayload` spans, with the same attribute names, as Honeycomb's subscriber. The span
/// shapes need no processor at all, only `MetricKitConfiguration(tracer:)` with Honeycomb's scope.
///
/// Diagnostic logs differ in three ways:
///
/// | Upstream (2.5.1 / 2.6.0)                              | Honeycomb today                                 |
/// | ----------------------------------------------------- | ----------------------------------------------- |
/// | `exception.stacktrace`                                | `metrickit.diagnostic.<kind>.exception.stacktrace_json` |
/// | adds `exception.type` and `exception.message`         | (none)                                          |
/// | sets the log record event name                        | no event name                                   |
///
/// `MetricKitConfiguration(useAppleStacktraceFormat: true)` makes the stack trace value identical.
/// This shaper moves it to the Honeycomb key and removes the additions.
public func metricKitLogRecordShaper(keepUpstreamAdditions: Bool = false) -> LogRecordShaper {
    return { record in
        guard record.instrumentationScopeInfo.name == honeycombMetricKitScope,
            case .string(let name)? = record.attributes["name"],
            name.hasPrefix(diagnosticNamePrefix)
        else { return record }

        var attributes = record.attributes
        if let stacktrace = attributes.removeValue(forKey: "exception.stacktrace") {
            attributes["\(name).exception.stacktrace_json"] = stacktrace
        }
        if !keepUpstreamAdditions {
            attributes.removeValue(forKey: "exception.type")
            attributes.removeValue(forKey: "exception.message")
        }

        return ReadableLogRecord(
            resource: record.resource,
            instrumentationScopeInfo: record.instrumentationScopeInfo,
            timestamp: record.timestamp,
            observedTimestamp: record.observedTimestamp,
            spanContext: record.spanContext,
            severity: record.severity,
            body: record.body,
            attributes: attributes,
            eventName: keepUpstreamAdditions ? record.eventName : nil
        )
    }
}
