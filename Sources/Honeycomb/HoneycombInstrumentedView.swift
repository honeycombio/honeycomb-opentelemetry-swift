import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

private let honeycombInstrumentedViewName = "@honeycombio/instrumentation-view"

struct HoneycombInstrumentedView: ViewModifier {
    private let span: Span
    private let name: String

    init(name: String) {
        self.name = name

        span = getMetricKitTracer().spanBuilder(spanName: "ViewInstrumentation")
            .setStartTime(time: Date())
            .setAttribute(key: "ViewName", value: name)
            .startSpan()

        print("\(name) init")
    }

    func body(content: Content) -> some View {
        print("\(name) started rendering")
        let start = Date()

        print("\(name) finished rendering")
        span.setAttribute(
            key: "RenderTimeMicroSeconds",
            value: Int(Date().timeIntervalSince(start).toMicroseconds)
        )

        return content.onAppear {
            span.end(time: Date())
        }
    }
}

extension View {
    func honeycombInstrumentedView(name: String) -> some View {
        modifier(HoneycombInstrumentedView(name: name))
    }
}

func getViewTracer() -> Tracer {
    return OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: honeycombInstrumentedViewName,
        instrumentationVersion: honeycombLibraryVersion
    )
}
