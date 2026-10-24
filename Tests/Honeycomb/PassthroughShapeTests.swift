import InMemoryExporter
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import Honeycomb

// opentelemetry-swift-core's InMemoryLogRecordExporter has no public initializer.
private final class CapturingLogExporter: LogRecordExporter, @unchecked Sendable {
    private(set) var records: [ReadableLogRecord] = []
    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        records.append(contentsOf: logRecords)
        return .success
    }
    func shutdown(explicitTimeout: TimeInterval?) {}
    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }
}

/// These tests feed the shapers the attributes that upstream opentelemetry-swift 2.5.1 / 2.6.0 sets
/// (taken from its source, not captured from a device) and check what Honeycomb would export.
final class PassthroughShapeTests: XCTestCase {
    // MARK: spans

    private func export(
        scope: String,
        status: Status = .unset,
        attributes: [String: AttributeValue],
        shaper: @escaping SpanShaper
    ) -> SpanData {
        let inMemory = InMemoryExporter()
        let provider = TracerProviderBuilder()
            .add(
                spanProcessor: SimpleSpanProcessor(
                    spanExporter: ShapingSpanExporter(inner: inMemory, shapers: [shaper])
                )
            )
            .build()
        let span = provider.get(instrumentationName: scope, instrumentationVersion: nil)
            .spanBuilder(spanName: "GET").startSpan()
        for (k, v) in attributes { span.setAttribute(key: k, value: v) }
        span.status = status
        span.end()
        provider.forceFlush()  // SimpleSpanProcessor exports asynchronously.
        return inMemory.getFinishedSpanItems()[0]
    }

    func testHttpErrorStatusIsUnsetAndSchemeIsRenamed() {
        let span = export(
            scope: honeycombURLSessionScope,
            status: .error(description: "404"),
            attributes: [
                "url.scheme": .string("https"), "url.path": .string("/missing"),
                "http.response.status_code": .int(404), "http.request.method": .string("GET"),
            ],
            shaper: urlSessionSpanShaper()
        )
        XCTAssertEqual(span.status, .unset)
        XCTAssertEqual(span.attributes["http.scheme"], .string("https"))
        XCTAssertNil(span.attributes["url.scheme"])
        XCTAssertNil(span.attributes["url.path"])
        XCTAssertEqual(span.attributes["http.response.status_code"], .int(404))
    }

    func testTransportFailureKeepsErrorStatusAndDropsStatusCodeZero() {
        let span = export(
            scope: honeycombURLSessionScope,
            status: .error(description: "The request timed out."),
            attributes: [
                "http.response.status_code": .int(0),
                "error.type": .string("NSURLErrorDomain.-1001"),
            ],
            shaper: urlSessionSpanShaper()
        )
        XCTAssertEqual(span.status, .error(description: "The request timed out."))
        XCTAssertNil(span.attributes["http.response.status_code"])
    }

    func testOtherScopesAreNotTouched() {
        let span = export(
            scope: "com.example.app",
            status: .error(description: "boom"),
            attributes: ["url.scheme": .string("https"), "http.response.status_code": .int(0)],
            shaper: urlSessionSpanShaper()
        )
        XCTAssertEqual(span.status, .error(description: "boom"))
        XCTAssertEqual(span.attributes["url.scheme"], .string("https"))
        XCTAssertEqual(span.attributes["http.response.status_code"], .int(0))
    }

    func testKeepUpstreamAdditions() {
        let span = export(
            scope: honeycombURLSessionScope,
            attributes: ["url.path": .string("/a"), "http.response.body.size": .int(5)],
            shaper: urlSessionSpanShaper(keepUpstreamAdditions: true)
        )
        XCTAssertEqual(span.attributes["url.path"], .string("/a"))
        XCTAssertEqual(span.attributes["http.response.body.size"], .int(5))
    }

    // MARK: logs

    private func shape(
        _ shapers: [LogRecordShaper],
        scope: String,
        eventName: String? = nil,
        attributes: [String: AttributeValue]
    ) -> [ReadableLogRecord] {
        let inMemory = CapturingLogExporter()
        let provider = LoggerProviderBuilder()
            .with(
                processors: [
                    ShapeLogRecordProcessor(
                        next: SimpleLogRecordProcessor(logRecordExporter: inMemory),
                        shapers: shapers
                    )
                ]
            )
            .build()
        var builder = provider.get(instrumentationScopeName: scope).logRecordBuilder()
            .setAttributes(attributes)
        if let eventName { builder = builder.setEventName(eventName) }
        builder.emit()
        return inMemory.records
    }

    func testMetricKitDiagnosticStacktraceMovesToTheKindOfDiagnostic() {
        let crash = shape(
            [metricKitLogRecordShaper()],
            scope: honeycombMetricKitScope,
            eventName: "metrickit.diagnostic.crash",
            attributes: [
                "name": .string("metrickit.diagnostic.crash"),
                "exception.stacktrace": .string("{}"),
                "exception.type": .string("EXC_BAD_ACCESS"),
                "exception.message": .string("m"),
                "metrickit.diagnostic.crash.exception.signal": .int(11),
            ]
        )[0]
        XCTAssertEqual(
            crash.attributes["metrickit.diagnostic.crash.exception.stacktrace_json"],
            .string("{}")
        )
        XCTAssertEqual(
            Set(crash.attributes.keys),
            [
                "name", "metrickit.diagnostic.crash.exception.stacktrace_json",
                "metrickit.diagnostic.crash.exception.signal",
            ]
        )
        XCTAssertNil(crash.eventName)
    }

    func testMetricKitShaperIgnoresOtherScopesAndNonDiagnostics() {
        let other = shape(
            [metricKitLogRecordShaper()],
            scope: "com.example.app",
            attributes: [
                "name": .string("metrickit.diagnostic.hang"), "exception.stacktrace": .string("x"),
            ]
        )[0]
        XCTAssertEqual(other.attributes["exception.stacktrace"], .string("x"))

        let notDiagnostic = shape(
            [metricKitLogRecordShaper()],
            scope: honeycombMetricKitScope,
            attributes: ["exception.stacktrace": .string("x")]
        )[0]
        XCTAssertEqual(notDiagnostic.attributes["exception.stacktrace"], .string("x"))
    }

    func testUpstreamCrashMovesToHoneycombErrorScopeAsFatal() {
        let crash = shape(
            [upstreamCrashLogRecordShaper()],
            scope: "io.opentelemetry.kscrash",
            eventName: "device.crash",
            attributes: ["exception.type": .string("crash")]
        )[0]
        XCTAssertEqual(crash.instrumentationScopeInfo.name, honeycombErrorScope)
        XCTAssertEqual(crash.severity, .fatal)

        let other = shape(
            [upstreamCrashLogRecordShaper()],
            scope: "io.opentelemetry.kscrash",
            eventName: "something.else",
            attributes: [:]
        )[0]
        XCTAssertEqual(other.instrumentationScopeInfo.name, "io.opentelemetry.kscrash")
        XCTAssertNil(other.severity)
    }

    func testShaperReturningNilDropsTheRecord() {
        XCTAssertTrue(shape([{ _ in nil }], scope: "s", attributes: [:]).isEmpty)
    }
}
