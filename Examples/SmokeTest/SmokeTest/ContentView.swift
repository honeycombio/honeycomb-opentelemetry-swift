import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

@testable import Honeycomb

private func sendSimpleSpan() {
    let tracerProvider = OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: "@honeycombio/smoke-test",
        instrumentationVersion: nil
    )
    let span = tracerProvider.spanBuilder(spanName: "test-span").startSpan()
    span.end()
}

private func sendFakeMetrics() {
    reportMetrics(payload: FakeMetricPayload())
    if #available(iOS 14.0, *) {
        reportDiagnostics(payload: FakeDiagnosticPayload())
    }
}

private func flush() {
    let tracerProvider = OpenTelemetry.instance.tracerProvider as! TracerProviderSdk
    tracerProvider.forceFlush()
    // tracerProvider.forceFlush() starts an async http operation, and holds only a weak
    // reference to itself. So, if the test quits immediately, the whole thing will be
    // garbage-collected and the http request will never be sent. Until that behavior is
    // fixed, it's necessary to sleep here, to allow the outstanding HTTP requests to be
    // processed.
    Thread.sleep(forTimeInterval: 3.0)
}

struct ContentView: View {
    var body: some View {
        VStack(
            alignment: .center,
            spacing: 20.0
        ) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)

            Text("This is a sample app.")

            Button(action: sendSimpleSpan) {
                Text("Send simple span")
            }
            .buttonStyle(.bordered)

            Button(action: sendFakeMetrics) {
                Text("Send fake MetricKit data")
            }
            .buttonStyle(.bordered)

            Button(action: flush) {
                Text("Flush")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
