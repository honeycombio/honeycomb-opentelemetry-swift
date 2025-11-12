#if os(iOS) && !targetEnvironment(macCatalyst)
    import Foundation
    import NetworkStatus
    import OpenTelemetryApi
    import OpenTelemetrySdk

    public struct NetworkStatusSpanProcessor: SpanProcessor {
        public let isStartRequired = true
        public let isEndRequired = false

        private let networkMonitor: NetworkMonitor
        private let networkStatus: NetworkStatus
        private let injector: NetworkStatusInjector

        init(monitor: NetworkMonitor) {
            networkMonitor = monitor
            // Initialize NetworkStatus once during processor creation to avoid
            // CTTelephonyNetworkInfo initialization issues on background threads.
            // This ensures CTTelephonyNetworkInfo is initialized during Honeycomb setup
            // (typically on main thread) rather than on background queues like MetricKit's,
            // which can cause hangs and XPC connection issues.
            //
            // Note: NetworkStatus holds a reference to NetworkMonitor, which actively
            // monitors network state changes. When inject() is called, it should query
            // the monitor for current state rather than using stale cached data.
            // This provides both thread safety and up-to-date network information.
            networkStatus = NetworkStatus(with: monitor)
            injector = NetworkStatusInjector(netstat: networkStatus)
        }

        public func onStart(
            parentContext: SpanContext?,
            span: any ReadableSpan
        ) {
            // Reuse the cached NetworkStatus and injector. The NetworkMonitor reference
            // within NetworkStatus should provide current network state on each injection.
            injector.inject(span: span)
        }

        public func onEnd(span: any ReadableSpan) {}

        public func shutdown(explicitTimeout: TimeInterval? = nil) {}

        public func forceFlush(timeout: TimeInterval? = nil) {}
    }
#endif
