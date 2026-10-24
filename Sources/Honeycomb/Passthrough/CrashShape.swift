import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Scope used by `Honeycomb.log(error:)` and by the uncaught-exception handler today.
let honeycombErrorScope = "io.honeycomb.error"

/// The upstream `Crash` instrumentation (KSCrash based, on `main` of opentelemetry-swift, not in
/// 2.6.0) reports a crash on the next launch as a log record with event name `device.crash`, scope
/// `io.opentelemetry.kscrash`, and `exception.type`, `exception.message`, `exception.stacktrace`.
///
/// Honeycomb's uncaught-exception handler reports an `NSException` in-process as a fatal log record
/// in scope `io.honeycomb.error` with the same three attribute names. This shaper moves a crash
/// record into Honeycomb's scope and severity so that "show me fatal errors" still finds it.
///
/// It cannot make the data the same: the stack trace is an Apple-format report rather than
/// `callStackSymbols`, `thread.name` is absent, and the timestamp is the time of the crash.
public func upstreamCrashLogRecordShaper() -> LogRecordShaper {
    return { record in
        guard record.eventName == "device.crash" else { return record }
        return ReadableLogRecord(
            resource: record.resource,
            instrumentationScopeInfo: InstrumentationScopeInfo(
                name: honeycombErrorScope,
                version: record.instrumentationScopeInfo.version
            ),
            timestamp: record.timestamp,
            observedTimestamp: record.observedTimestamp,
            spanContext: record.spanContext,
            severity: .fatal,
            body: record.body,
            attributes: record.attributes,
            eventName: record.eventName
        )
    }
}
