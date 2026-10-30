import Foundation
import Honeycomb
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk

// Passthrough experiment harness. Runs on Linux. It sends telemetry to a local OTLP sink.
//
//   PassthroughHarness current      Honeycomb.configure with today's defaults; emits what Honeycomb's
//                                   own instrumentation emits (fixtures-honeycomb.json).
//   PassthroughHarness upstream     Bare opentelemetry-swift; emits what upstream's instrumentation
//                                   emits with its default configuration (fixtures-upstream.json, "raw").
//   PassthroughHarness passthrough  Honeycomb.configure with the upstream URLSession and MetricKit
//                                   flags on, so the shapers run; emits upstream's output with
//                                   Honeycomb's configuration applied ("configured").
//
// Fixtures are hand-built from the sources of both SDKs. Nothing here runs the Apple-only
// instrumentation itself.

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: PassthroughHarness current|upstream|passthrough FIXTURE_DIR [ENDPOINT]")
    exit(2)
}
let mode = args[1]
let dir = URL(fileURLWithPath: args[2])
let endpoint = args.count > 3 ? args[3] : "http://127.0.0.1:4318"
let fakeKey = "0123456789abcdef0123456789abcdef"  // fake, shaped like a classic key on purpose
let baseTime = 1_700_000_000.0

func load(_ name: String) -> [[String: Any]] {
    let data = try! Data(contentsOf: dir.appendingPathComponent(name))
    return (try! JSONSerialization.jsonObject(with: data) as! [String: Any])["fixtures"]
        as! [[String: Any]]
}
let stack =
    try! JSONSerialization.jsonObject(
        with: Data(contentsOf: dir.appendingPathComponent("stacktraces.json"))
    ) as! [String: String]

func attributeValue(_ v: Any, stacktrace: String) -> AttributeValue {
    switch v {
    case let s as String: return .string(s == "@stacktrace" ? stacktrace : s)
    case let n as NSNumber:
        return String(cString: n.objCType) == "d" ? .double(n.doubleValue) : .int(n.intValue)
    default: fatalError("unsupported fixture value \(v)")
    }
}

/// Emits one fixture. The start / log timestamp encodes the fixture's index so that runs can be paired.
func emit(
    _ f: [String: Any],
    index: Int,
    scope: String,
    scopeVersion: String?,
    name: String?,
    stacktrace: String,
    extra: (Span) -> Void = { _ in }
) {
    let ts = Date(timeIntervalSince1970: baseTime + Double(index))
    let attrs = (f["attributes"] as! [String: Any])
        .mapValues { attributeValue($0, stacktrace: stacktrace) }
    if f["kind"] as? String == "span" {
        let tracer = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: scope,
            instrumentationVersion: scopeVersion
        )
        let span = tracer.spanBuilder(spanName: name ?? (f["name"] as! String))
            .setSpanKind(spanKind: .client).setStartTime(time: ts).startSpan()
        for (k, v) in attrs { span.setAttribute(key: k, value: v) }
        if let status = f["status"] as? [String: String], let message = status["error"] {
            span.status = .error(description: message)
        }
        extra(span)
        span.end(time: ts.addingTimeInterval(0.01))
    } else {
        let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: scope)
        var b = logger.logRecordBuilder().setTimestamp(ts).setAttributes(attrs)
        if let e = f["eventName"] as? String { b = b.setEventName(e) }
        if f["severity"] as? String == "fatal" { b = b.setSeverity(.fatal) }
        b.emit()
    }
}

func flushAll() {
    (OpenTelemetry.instance.tracerProvider as? TracerProviderSdk)?.forceFlush()
    _ = (OpenTelemetry.instance.meterProvider as? MeterProviderSdk)?.forceFlush()
}

func honeycombOptions(upstreamInstrumentation: Bool) throws -> HoneycombOptions {
    try HoneycombOptions.Builder()
        .setAPIKey(fakeKey)
        .setDataset("harness-dataset")
        .setServiceName("passthrough-harness")
        .setServiceVersion("0.0.1")
        .setAPIEndpoint(endpoint)
        .setSampleRate(1)
        .setResourceAttributes(["deployment.environment": "harness"])
        .setOTELURLSessionInstrumentationEnabled(upstreamInstrumentation)
        .setOTELMetricKitInstrumentationEnabled(upstreamInstrumentation)
        .build()
}

switch mode {
case "current", "passthrough":
    let passthrough = mode == "passthrough"
    try Honeycomb.configure(options: try honeycombOptions(upstreamInstrumentation: passthrough))
    let fixtures = passthrough ? load("fixtures-upstream.json") : load("fixtures-honeycomb.json")
    for (i, f) in fixtures.enumerated() {
        let scopeInfo =
            passthrough
            ? (f["configured"] as! [String: String])
            : [
                "scope": f["scope"] as! String, "name": f["name"] as? String ?? "",
            ]
        // Honeycomb's configuration (not the shapers) decides these in passthrough mode: the tracer
        // scope, the span name, and the attributes added by the receivedError hook.
        emit(
            f,
            index: i,
            scope: scopeInfo["scope"]!,
            scopeVersion: nil,
            name: scopeInfo["name"],
            stacktrace: stack["apple"]!
        ) { span in
            if passthrough, let te = f["transportError"] as? [String: Any] {
                recordTransportFailure(
                    on: span,
                    error: NSError(
                        domain: te["domain"] as! String,
                        code: te["code"] as! Int,
                        userInfo: [NSLocalizedDescriptionKey: te["message"] as! String]
                    )
                )
            }
        }
        usleep(2000)
    }
    // Honeycomb's own, bespoke code paths that have no upstream equivalent. Same in both modes.
    Honeycomb.setCurrentScreen(path: "Home", reason: "harness")
    Honeycomb.setCurrentScreen(path: "Detail", reason: "harness")
    Honeycomb.log(error: NSError(domain: "HarnessDomain", code: 7), thread: nil)
    OpenTelemetry.instance.tracerProvider
        .get(instrumentationName: "harness", instrumentationVersion: nil)
        .spanBuilder(spanName: "custom").startSpan().end()
    var counter = OpenTelemetry.instance.meterProvider.get(name: "harness")
        .counterBuilder(name: "harness.count").build()
    counter.add(value: 1)
    flushAll()

case "upstream":
    // What a team gets by wiring upstream directly, with only the exporter configuration filled in.
    let headers = [("x-honeycomb-team", fakeKey), ("x-honeycomb-dataset", "harness-dataset")]
    let cfg = OtlpConfiguration(timeout: 10, headers: headers)
    let resource = Resource()
        .merging(other: Resource(attributes: ["service.name": .string("passthrough-harness")]))
    let exporter = OtlpHttpTraceExporter(
        endpoint: URL(string: endpoint + "/v1/traces")!,
        config: cfg
    )
    let tracerProvider = TracerProviderBuilder()
        .add(spanProcessor: BatchSpanProcessor(spanExporter: exporter)).with(resource: resource)
        .build()
    let logExporter = OtlpHttpLogExporter(
        endpoint: URL(string: endpoint + "/v1/logs")!,
        config: cfg
    )
    let loggerProvider = LoggerProviderBuilder()
        .with(processors: [SimpleLogRecordProcessor(logRecordExporter: logExporter)])
        .with(resource: resource).build()
    // Upstream's own examples register a catch-all view; without one no instrument records anything.
    let metricExporter = OtlpHttpMetricExporter(
        endpoint: URL(string: endpoint + "/v1/metrics")!,
        config: cfg
    )
    let meterProvider = MeterProviderSdk.builder()
        .registerMetricReader(reader: PeriodicMetricReaderBuilder(exporter: metricExporter).build())
        .registerView(
            selector: InstrumentSelector.builder().setInstrument(name: ".*").build(),
            view: View.builder().build()
        )
        .setResource(resource: resource).build()
    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
    OpenTelemetry.registerMeterProvider(meterProvider: meterProvider)
    var counter = meterProvider.get(name: "harness").counterBuilder(name: "harness.count").build()
    counter.add(value: 1)
    for (i, f) in load("fixtures-upstream.json").enumerated() {
        let raw = f["raw"] as! [String: String]
        emit(
            f,
            index: i,
            scope: raw["scope"]!,
            scopeVersion: raw["scopeVersion"],
            name: raw["name"],
            stacktrace: stack["otel"]!
        )
        usleep(2000)
    }
    OpenTelemetry.instance.tracerProvider
        .get(instrumentationName: "harness", instrumentationVersion: nil)
        .spanBuilder(spanName: "custom").startSpan().end()
    flushAll()

default:
    print("unknown mode \(mode)")
    exit(2)
}
// Give the batch exporters a moment to finish their HTTP requests.
sleep(2)
