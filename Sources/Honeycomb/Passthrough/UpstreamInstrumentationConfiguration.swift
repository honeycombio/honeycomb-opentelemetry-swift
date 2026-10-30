import Foundation
import OpenTelemetryApi

// NOTE: everything in this file is Apple-only and was NOT compiled or run in the Linux container
// that produced the rest of this experiment. It was written against the sources of
// opentelemetry-swift 2.5.1 / 2.6.0 and needs a macOS build before it can be trusted.

#if canImport(URLSessionInstrumentation)
    import URLSessionInstrumentation

    /// Returns true if this request is one of the SDK's own OTLP exports, so that the SDK does not
    /// create spans for its own network traffic. Same check as Honeycomb's own instrumentation.
    private func isOTLPExportRequest(_ request: URLRequest) -> Bool {
        request.allHTTPHeaderFields?.keys.contains("x-otlp-version") ?? false
    }

    /// Configures upstream `URLSessionInstrumentation` to emit Honeycomb's span shape as closely as
    /// configuration allows. `urlSessionSpanShaper()` closes the rest at export time.
    public func makeHoneycombURLSessionConfiguration() -> URLSessionInstrumentationConfiguration {
        // Upstream's default scope is "NSURLSession". Keep the scope Honeycomb users query on.
        let tracer = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: honeycombURLSessionScope,
            instrumentationVersion: honeycombLibraryVersion
        )
        return URLSessionInstrumentationConfiguration(
            // Without this, upstream creates a span for every OTLP export request.
            shouldInstrument: { request in !isOTLPExportRequest(request) },
            // Honeycomb names the span after the method alone. Upstream's default is "HTTP GET".
            nameSpan: { request in request.httpMethod ?? "UNKNOWN" },
            // Honeycomb has never injected `traceparent` itself (the README tells apps to do it).
            // Upstream does by default. Return true here to accept upstream's behavior.
            shouldInjectTracingHeaders: { _ in false },
            // Upstream calls this just before it ends a span for a failed request, after it has set
            // `http.response.status_code = 0`. Add the attributes Honeycomb adds for these failures.
            receivedError: { error, _, _, span in recordTransportFailure(on: span, error: error) },
            tracer: tracer,
            semanticConvention: .stable
        )
    }
#endif

#if canImport(MetricKitInstrumentation) && canImport(MetricKit) && !os(tvOS) && !os(macOS)
    import MetricKit
    import MetricKitInstrumentation

    /// Configures upstream `MetricKitInstrumentation` to use Honeycomb's scope for spans and logs and
    /// to report stack traces in Apple's native JSON, as Honeycomb's own subscriber does.
    /// `metricKitLogRecordShaper()` moves the stack trace to Honeycomb's attribute name.
    @available(iOS 13.0, *)
    public func makeHoneycombMetricKitConfiguration() -> MetricKitConfiguration {
        MetricKitConfiguration(
            useAppleStacktraceFormat: true,
            tracer: OpenTelemetry.instance.tracerProvider.get(
                instrumentationName: honeycombMetricKitScope,
                instrumentationVersion: honeycombLibraryVersion
            ),
            logger: OpenTelemetry.instance.loggerProvider.get(
                instrumentationScopeName: honeycombMetricKitScope
            )
        )
    }

    /// A second upstream subscriber, configured like the one `Honeycomb.configure` installs. It lets
    /// the smoke test app feed fake MetricKit payloads through upstream's `didReceive(_:)`, because
    /// upstream's `reportMetrics` and `reportDiagnostics` are internal.
    @available(iOS 13.0, *)
    public func makeHoneycombMetricKitSubscriber() -> MXMetricManagerSubscriber {
        MetricKitInstrumentation(configuration: makeHoneycombMetricKitConfiguration())
    }
#endif
