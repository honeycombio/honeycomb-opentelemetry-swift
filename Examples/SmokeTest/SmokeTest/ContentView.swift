import Honeycomb
import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

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
    @State private var sessionId: String = "🐝💭"
    @State private var sessionStartTime: String = "🐝💭"
    @State private var timer: Timer?
    func updateSessionId() {
        sessionId =
        UserDefaults.standard
            .string(forKey: "session.id") ?? "🐝🫥"
        let date =
        UserDefaults.standard
            .object(forKey: "session.startTime") as! Date
        sessionStartTime = date.ISO8601Format().description

    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateSessionId()
        }
    }

    var body: some View {
        TabView {
            VStack(
                alignment: .center,
                spacing: 20.0
            ) {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)

                Text("This is a sample app.")
                VStack(alignment: .leading) {
                    Text("Session Id: \(sessionId)")
                        .font(.caption)
                    Text("Start Time: \(sessionStartTime)")
                        .font(.caption)
                }
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
            .tabItem { Label("Core", systemImage: "house") }
            .onAppear {
                Honeycomb.setCurrentScreen(path: "Core")
            }

            NetworkView()
                .padding()
                .tabItem { Label("Network", systemImage: "network") }
                .onAppear {
                    Honeycomb.setCurrentScreen(path: "Network")
                }

            ViewInstrumentationView()
                .padding()
                .tabItem { Label("View Instrumentation", systemImage: "ruler") }
                .onAppear {
                    Honeycomb.setCurrentScreen(path: "View Instrumentation")
                }

            UIKitView()
                .padding()
                .tabItem {
                    Label(
                        "UIKit",
                        systemImage: "paintpalette"
                    )
                }
                .onAppear {
                    Honeycomb.setCurrentScreen(path: "UIKit")
                }

            NavigationExamplesView()
                .padding()
                .tabItem { Label("Navigation", systemImage: "globe") }
        }

        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
}

#Preview {
    ContentView()
}
