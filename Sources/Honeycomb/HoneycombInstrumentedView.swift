import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

private let honeycombInstrumentedViewName = "@honeycombio/instrumentation-view"

struct HoneycombInstrumentedView<Content: View>: View {
    private let span: Span
    private let content: () -> Content
    private let name: String

    init(name: String, @SwiftUICore.ViewBuilder _ content: @escaping () -> Content) {
        self.name = name
        self.content = content

        span = getMetricKitTracer().spanBuilder(spanName: "ViewInstrumentation")
            .setStartTime(time: Date())
            .setAttribute(key: "ViewName", value: name)
            .startSpan()

        print("\(name) init")
    }

    var body: some View {
        print("\(name) started rendering")
        let start = Date()

        let c = content()

        print("\(name) finished rendering")
        span.setAttribute(
            key: "RenderTimeMicroSeconds",
            value: Int(Date().timeIntervalSince(start).toMicroseconds)
        )

        return c.onAppear {
            span.end(time: Date())
        }
    }
}

func getViewTracer() -> Tracer {
    return OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: honeycombInstrumentedViewName,
        instrumentationVersion: honeycombLibraryVersion
    )
}
