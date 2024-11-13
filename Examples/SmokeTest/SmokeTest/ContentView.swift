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

struct ExpensiveView: View {
    var body: some View {
        HStack {
            Text("test:")
            HoneycombInstrumentedView(name: "nested expensive text") {
                Text(String(timeConsumingCalculation()))
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        HoneycombInstrumentedView(name: "main view") {
            VStack(
                alignment: .center,
                spacing: 20.0
            ) {
                HoneycombInstrumentedView(name: "expensive text 1") {
                    Text(String(timeConsumingCalculation()))
                }

                HoneycombInstrumentedView(name: "home icon") {
                    Image(systemName: "globe")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                }

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

                HoneycombInstrumentedView(name: "expensive text 2") {
                    Text(String(timeConsumingCalculation()))
                }

                HoneycombInstrumentedView(name: "expensive text 3") {
                    Text(String(timeConsumingCalculation()))
                }

                HoneycombInstrumentedView(name: "nested expensive view") {
                    ExpensiveView()
                }

                HoneycombInstrumentedView(name: "expensive text 4") {
                    Text(String(timeConsumingCalculation()))
                }

            }
            .padding()
        }
    }
}

private func timeConsumingCalculation() -> Int {
    print("starting time consuming calculation")
    return (1...10_000_000).reduce(0, +)
}

#Preview {
    ContentView()
}
