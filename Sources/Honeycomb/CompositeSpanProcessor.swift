import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

internal class CompositeSpanProcessor: SpanProcessor {
    private var spanProcessors: [SpanProcessor] = []
    var isStartRequired: Bool {
        spanProcessors.contains(where: { $0.isStartRequired })
    }
    var isEndRequired: Bool {
        spanProcessors.contains(where: { $0.isEndRequired })
    }

    func addSpanProcessor(_ spanProcessor: SpanProcessor) {
        spanProcessors.append(spanProcessor)
    }

    func onStart(
        parentContext: OpenTelemetryApi.SpanContext?,
        span: any OpenTelemetrySdk.ReadableSpan
    ) {
        spanProcessors.forEach({ $0.onStart(parentContext: parentContext, span: span) })
    }

    func onEnd(span: any OpenTelemetrySdk.ReadableSpan) {
        for var spanProcessor in spanProcessors {
            spanProcessor.onEnd(span: span)
        }
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        for var spanProcessor in spanProcessors {
            spanProcessor.shutdown(explicitTimeout: explicitTimeout)
        }
    }

    func forceFlush(timeout: TimeInterval?) {
        for spanProcessor in spanProcessors {
            spanProcessor.forceFlush(timeout: timeout)
        }
    }
}
