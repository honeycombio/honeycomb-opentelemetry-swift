import Foundation
import NetworkStatus
import OpenTelemetryApi
import OpenTelemetrySdk

public struct NetworkStatusSpanProcessor: SpanProcessor {
    public let isStartRequired = true
    public let isEndRequired = false

    private let networkMonitor: NetworkMonitor

    init(monitor: NetworkMonitor) {
        networkMonitor = monitor
    }

    public func onStart(
        parentContext: SpanContext?,
        span: any ReadableSpan
    ) {
        let status = NetworkStatus(with: networkMonitor)
        let injector = NetworkStatusInjector(netstat: status)
        injector.inject(span: span)
    }

    public func onEnd(span: any ReadableSpan) {}

    public func shutdown(explicitTimeout: TimeInterval? = nil) {}

    public func forceFlush(timeout: TimeInterval? = nil) {}
}
