import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

internal class SampleSpanProcessor: SpanProcessor {
    public let isStartRequired = true
    public let isEndRequired = false

    public func onStart(
        parentContext: SpanContext?,
        span: any ReadableSpan
    ) {
        span.setAttribute(
            key: "app.metadata",
            value: "extra metadata"
        )
    }

    func onEnd(span: any OpenTelemetrySdk.ReadableSpan) {}

    func shutdown(explicitTimeout: TimeInterval?) {}

    func forceFlush(timeout: TimeInterval?) {}

}
