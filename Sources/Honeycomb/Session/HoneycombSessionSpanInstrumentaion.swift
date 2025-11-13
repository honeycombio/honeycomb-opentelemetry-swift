import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

struct HoneycombSessionIdSpanProcessor: SpanProcessor {
    public let isStartRequired = true
    public let isEndRequired = false
    private var sessionManager: HoneycombSessionManager

    init(sessionManager: HoneycombSessionManager) {
        self.sessionManager = sessionManager
    }

    public func onStart(
        parentContext: SpanContext?,
        span: any ReadableSpan
    ) {
        span.setAttribute(
            key: SemanticConventions.Session.id,
            value: sessionManager.session.id
        )
    }

    public func onEnd(span: any ReadableSpan) {}

    public func shutdown(explicitTimeout: TimeInterval? = nil) {}

    public func forceFlush(timeout: TimeInterval? = nil) {}
}
