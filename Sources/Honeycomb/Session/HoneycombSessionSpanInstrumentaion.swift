import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public struct HoneycombSessionIdSpanProcessor: SpanProcessor {
    public let isStartRequired = true
    public let isEndRequired = false
    private var sessionManager: HoneycombSessionManager

    public init(
        debug: Bool = false,
        sessionLifetimeSeconds: TimeInterval
    ) {
        self.sessionManager = HoneycombSessionManager(
            debug: debug,
            sessionLifetimeSeconds: sessionLifetimeSeconds
        )
    }

    public func onStart(
        parentContext: SpanContext?,
        span: any ReadableSpan
    ) {
        span.setAttribute(
            key: "session.id",
            value: sessionManager.sessionId
        )
    }

    public func onEnd(span: any ReadableSpan) {}

    public func shutdown(explicitTimeout: TimeInterval? = nil) {}

    public func forceFlush(timeout: TimeInterval? = nil) {}
}
