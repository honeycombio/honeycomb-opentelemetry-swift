import OpenTelemetryApi
import SwiftUI

private let honeycombInstrumentedViewName = "@honeycombio/instrumentation-view"

struct HoneycombInstrumentedView<Content: View>: View {
    private let span: Span
    private let content: () -> Content
    private let name: String
    private let initTime: Date

    init(name: String, @ViewBuilder _ content: @escaping () -> Content) {
        self.initTime = Date()
        self.name = name
        self.content = content

        self.span = getViewTracer().spanBuilder(spanName: "View Render")
            .setStartTime(time: Date())
            .setAttribute(key: "ViewName", value: name)
            .startSpan()
    }

    var body: some View {
        let start = Date()

        // contents start init
        let bodySpan = getViewTracer().spanBuilder(spanName: "View Body")
            .setStartTime(time: Date())
            .setAttribute(key: "ViewName", value: name)
            .setParent(span)
            .setActive(true)
            .startSpan()

        let c = content()
        // contents end init

        // we don't end `bodySpan` here so that it remains active in context
        //   that way subsequent spans get nested in correctly
        //   but we are going to want to track how long it took, so we need to store the endTime:
        let endTime = Date()

        span.setAttribute(
            key: "RenderDuration",
            value: endTime.timeIntervalSince(start)
        )

        return c.onAppear {
            // contents end render
            // we haven't ended `bodySpan` yet because we wanted it to remain active in context
            //   now we need to end it, and we pass in the endTime from earlier, when the body actually
            //   finished rendering. Otherwise this span would stretch out to cover the rendering time
            //   of other views in the tree, and we wouldn't get an accurate duration.
            bodySpan.end(time: endTime)

            let appearTime = Date()
            span.setAttribute(key: "TotalDuration", value: appearTime.timeIntervalSince(initTime))
            span.end(time: appearTime)
        }
    }
}

func getViewTracer() -> Tracer {
    return OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: honeycombInstrumentedViewName,
        instrumentationVersion: honeycombLibraryVersion
    )
}
