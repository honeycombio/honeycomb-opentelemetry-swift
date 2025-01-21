//
//  SessionManager.swift
//  honeycomb-opentelemetry-swift
//
//  Created by Wolfgang Therrien on 1/17/25.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class HoneycombSessionManager {
    private var sessionId: String = ""

    public func getSessionId() -> String {
        if sessionId.isEmpty {
            sessionId = UUID().uuidString
            UserDefaults().set(sessionId, forKey: "session.id")
        }
        return sessionId
    }
}

public struct HoneycombSessionIdSpanProcessor: SpanProcessor {
    public let isStartRequired = true
    public let isEndRequired = false
    private var sesssionManager: HoneycombSessionManager

    public init() {
        self.sesssionManager = HoneycombSessionManager()
    }

    public func onStart(
        parentContext: SpanContext?,
        span: any ReadableSpan
    ) {
        span.setAttribute(
            key: "session.id",
            value: sesssionManager.getSessionId()
        )
    }

    public func onEnd(span: any ReadableSpan) {}

    public func shutdown(explicitTimeout: TimeInterval? = nil) {}

    public func forceFlush(timeout: TimeInterval? = nil) {}
}
