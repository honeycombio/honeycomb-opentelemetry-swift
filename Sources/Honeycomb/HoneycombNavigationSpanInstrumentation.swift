import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

private let navigationInstrumentationName = "io.honeycomb.navigation"
private let navigationToSpanName = "NavigationTo"
private let navigationFromSpanName = "NavigationFrom"
private let unencodablePath = "<unencodable path>"

func getTracer() -> Tracer {
    return OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: navigationInstrumentationName,
        instrumentationVersion: honeycombLibraryVersion
    )
}

internal class HoneycombNavigationProcessor {
    static let shared = HoneycombNavigationProcessor()
    var currentNavigationPath: [String] = []
    var lastNavigationTime: Date? = nil

    private init() {
        setupAppLifecycleTracking()
    }

    @available(iOS 16.0, macOS 13.0, *)
    func reportNavigation(prefix: String? = nil, path: NavigationPath, reason: String? = nil) {
        if let codablePath = path.codable {
            reportNavigation(path: codablePath, reason: reason)
        } else {
            reportNavigation(path: unencodablePath, reason: reason)
        }
    }

    func reportNavigation(prefix: String? = nil, path: String, reason: String? = nil) {
        reportNavigation(path: [path], reason: reason)
    }

    func reportNavigation(prefix: String? = nil, path: Encodable, reason: String? = nil) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(path)
            let pathStr = String(decoding: data, as: UTF8.self)

            reportNavigation(path: pathStr, reason: reason)
        } catch {
            reportNavigation(path: unencodablePath, reason: reason)
        }
    }

    func reportNavigation(prefix: String? = nil, path: [String], reason: String? = nil) {
        // If we have a previous navigation, emit a "NavigationFrom" span
        navigationEnd(reason: reason ?? "navigation")

        // Update current path
        currentNavigationPath = path
        if prefix != nil {
            currentNavigationPath = [prefix!] + currentNavigationPath
        }

        navigationStart(reason: reason ?? "navigation")
    }

    func reportNavigation(prefix: String? = nil, path: [Encodable], reason: String? = nil) {
        do {
            let encoder = JSONEncoder()

            let pathStack =
                try path.map {
                    let encoded = try encoder.encode($0)
                    return String(decoding: encoded, as: UTF8.self)
                }

            reportNavigation(prefix: prefix, path: pathStack, reason: reason)
        } catch {
            reportNavigation(prefix: prefix, path: unencodablePath, reason: reason)
        }
    }

    func reportNavigation(prefix: String? = nil, path: Any, reason: String? = nil) {
        reportNavigation(prefix: prefix, path: unencodablePath, reason: reason)
    }

    func setCurrentNavigationPath(_ path: [String]) {
        currentNavigationPath = path
    }

    private func setupAppLifecycleTracking() {
        #if canImport(UIKit)
            let notificationCenter = NotificationCenter.default

            // Monitor foreground/background state changes
            notificationCenter.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                guard let self = self else { return }

                navigationStart(reason: "appDidBecomeActive")
            }

            notificationCenter.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                guard let self = self else { return }

                navigationEnd(reason: "appWillResignActive")
            }

            notificationCenter.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                guard let self = self else { return }

                navigationEnd(reason: "appDidEnterBackground")
            }

            notificationCenter.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                guard let self = self else { return }

                navigationEnd(reason: "appWillTerminate")
            }
        #endif
    }

    private func navigationEnd(reason: String) {
        if !self.currentNavigationPath.isEmpty, let screenName = self.currentNavigationPath.last {
            // Emit a NavigationTo span to indicate we're returning to this screen
            let span = getTracer().spanBuilder(spanName: navigationFromSpanName).startSpan()
            span.setAttribute(key: "screen.name", value: screenName)
            if let lastNavTime = self.lastNavigationTime {
                let activeTime = Date().timeIntervalSince(lastNavTime)
                span.setAttribute(key: "screen.active.time", value: Double(activeTime))
            }
            span.setAttribute(key: "navigation.trigger", value: reason)
            span.end()
        }
    }

    private func navigationStart(reason: String) {
        let screenName = self.currentNavigationPath.last ?? "/"

        // Emit a NavigationTo span to indicate we're returning to this screen
        let span = getTracer().spanBuilder(spanName: navigationToSpanName).startSpan()
        span.setAttribute(key: "screen.name", value: screenName)
        span.setAttribute(key: "navigation.trigger", value: reason)
        span.end()

        // Update the last navigation time to now
        self.lastNavigationTime = Date()
    }
}

extension View {
    @available(iOS 16.0, macOS 13.0, *)
    public func instrumentNavigation(
        prefix: String? = nil,
        path: NavigationPath,
        reason: String? = nil
    ) -> some View {
        HoneycombNavigationProcessor.shared.reportNavigation(
            prefix: prefix,
            path: path,
            reason: reason
        )

        return modifier(EmptyModifier())
    }

    public func instrumentNavigation(
        prefix: String? = nil,
        path: [Encodable],
        reason: String? = nil
    ) -> some View {
        HoneycombNavigationProcessor.shared.reportNavigation(
            prefix: prefix,
            path: path,
            reason: reason
        )

        return modifier(EmptyModifier())
    }
}

public struct HoneycombNavigationPathSpanProcessor: SpanProcessor {
    public let isStartRequired = true
    public let isEndRequired = false

    public func onStart(
        parentContext: SpanContext?,
        span: any ReadableSpan
    ) {
        let currentViewPath = HoneycombNavigationProcessor.shared.currentNavigationPath
        if !currentViewPath.isEmpty {
            span.setAttribute(
                key: "screen.name",
                value: currentViewPath.last!
            )
        }
        span.setAttribute(
            key: "screen.path",
            value: serializePath(currentViewPath)
        )
    }

    private func serializePath(_ path: [String]) -> String {
        return "/"
            + path
            .filter { str in
                !str.starts(with: ("_"))
            }
            .joined(separator: "/")
    }

    public func onEnd(span: any ReadableSpan) {}

    public func shutdown(explicitTimeout: TimeInterval? = nil) {}

    public func forceFlush(timeout: TimeInterval? = nil) {}
}
