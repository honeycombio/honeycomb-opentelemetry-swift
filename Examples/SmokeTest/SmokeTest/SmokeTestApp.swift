import Honeycomb
import OpenTelemetryApi
import SwiftUI

/// Set by the UI tests (from `TEST_RUNNER_SMOKE_UPSTREAM`) for the passthrough experiment: run the
/// same app with upstream's URLSession and MetricKit instrumentation plus Honeycomb's shapers.
let smokeTestUsesUpstreamInstrumentation =
    ProcessInfo.processInfo.environment["SMOKE_UPSTREAM"] == "1"

/// How long `Honeycomb.configure` took, as a span in its own scope. Indicative only: simulator, CI.
private func recordConfigureTiming(since started: Date, upstream: Bool) {
    let span = OpenTelemetry.instance.tracerProvider
        .get(instrumentationName: "io.honeycomb.smoke-test.timing", instrumentationVersion: nil)
        .spanBuilder(spanName: "configure")
        .startSpan()
    span.setAttribute(key: "configure.ms", value: Date().timeIntervalSince(started) * 1000)
    span.setAttribute(key: "upstream", value: upstream)
    span.end()
}

@main
struct SmokeTestApp: App {
    init() {
        do {
            let upstream = smokeTestUsesUpstreamInstrumentation
            let started = Date()
            let options = try HoneycombOptions.Builder()
                .setAPIKey("test-key")
                .setAPIEndpoint("http://localhost:4318")
                .setServiceName("ios-test")
                .setServiceVersion("0.0.1")
                .setDebug(true)
                .setSessionTimeout(10)
                .setSpanProcessor(SampleSpanProcessor())
                .setTouchInstrumentationEnabled(true)
                .setOTELURLSessionInstrumentationEnabled(upstream)
                .setOTELMetricKitInstrumentationEnabled(upstream)
                .build()
            try Honeycomb.configure(options: options)
            recordConfigureTiming(since: started, upstream: upstream)
        } catch {
            NSException(name: NSExceptionName("HoneycombOptionsError"), reason: "\(error)").raise()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
