import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public struct HoneycombBaggageSpanProcessor: SpanProcessor {
    public let isStartRequired = true
    public let isEndRequired = false
    public let filter: (Entry) -> Bool

    public func onStart(parentContext: OpenTelemetryApi.SpanContext?, span: any OpenTelemetrySdk.ReadableSpan) {
        if let baggage = OpenTelemetry.instance.contextProvider.activeBaggage {
            let filteredEntries = baggage.getEntries().filter(self.filter)
            for entry in filteredEntries {
                span.setAttribute(key: entry.key.name, value: entry.value.string)
            }
        }
    }

    public func onEnd(span: any OpenTelemetrySdk.ReadableSpan) {}

    public func shutdown(explicitTimeout: TimeInterval? = nil) {}

    public func forceFlush(timeout: TimeInterval? = nil) {}
}
