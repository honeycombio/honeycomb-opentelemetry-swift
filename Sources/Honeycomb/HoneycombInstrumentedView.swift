import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

private let honeycombInstrumentedViewName = "@honeycombio/instrumentation-view"

struct HoneycombInstrumentedView<Content: View>: View {
    private let span: Span
    private let content: () -> Content
    private let name: String
    private let initTime: Date

    init(name: String, @SwiftUICore.ViewBuilder _ content: @escaping () -> Content) {
        self.initTime = Date()
        self.name = name
        self.content = content

        self.span = getMetricKitTracer().spanBuilder(spanName: "View Render")
            .setStartTime(time: Date())
            .setAttribute(key: "ViewName", value: name)
            .startSpan()

        print("\(name) init")
    }

    var body: some View {
        print("\(name) body started rendering")
        let start = Date()

        // contents start init
        let bodySpan = getMetricKitTracer().spanBuilder(spanName: "View Body")
            .setStartTime(time: Date())
            .setAttribute(key: "ViewName", value: name)
            .setParent(span)
            .setActive(true)
            .startSpan()
        
        let c = content()
        
        let endTime = Date()
        // contents end init

        print("\(name) body finished rendering")
        span.setAttribute(
            key: "RenderTimeMicroSeconds",
            value: Int(endTime.timeIntervalSince(start).toMicroseconds)
        )

        return c.onAppear {
            // contents end render

            print("\(name) content appeared")
            span.setAttribute(key: "DurationMicroSecons", value: Int(Date().timeIntervalSince(initTime).toMicroseconds))
            span.end(time: Date())
            bodySpan.end(time: endTime)
        }
    }
}

func getViewTracer() -> Tracer {
    return OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: honeycombInstrumentedViewName,
        instrumentationVersion: honeycombLibraryVersion
    )
}
