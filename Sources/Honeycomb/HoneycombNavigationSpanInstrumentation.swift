import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

private let navigationInstrumentationName = "@honeycombio/instrumentation-navigation"
private let navigationSpanName = "Navigation"
private let unencodablePath = "<unencodable path>"

func getTracer() -> Tracer {
    return OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: navigationInstrumentationName,
        instrumentationVersion: honeycombLibraryVersion
    )
}

internal class HoneycombNavigationProcessor {
    static let shared = HoneycombNavigationProcessor()
    var currentNavigationPath: String? = nil

    private init() {}

    @available(iOS 16.0, macOS 12.0, *)
    func reportNavigation(path: NavigationPath) {
        if let codablePath = path.codable {
            reportNavigation(path: codablePath)
        } else {
            reportNavigation(path: unencodablePath)
        }
    }

    func reportNavigation(path: String) {
        currentNavigationPath = path

        // emit a span that says we've navigated to this path
        getTracer().spanBuilder(spanName: navigationSpanName)
            .setAttribute(key: "screen.name", value: path)
            .startSpan()
            .end()
    }

    func reportNavigation(path: Encodable) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(path)
            let pathStr = String(decoding: data, as: UTF8.self)

            reportNavigation(path: pathStr)
        } catch {
            reportNavigation(path: unencodablePath)
        }
    }

    func reportNavigation(path: [Encodable]) {
        do {
            let encoder = JSONEncoder()

            let pathStr =
                try path.map {
                    let encoded = try encoder.encode($0)
                    return String(decoding: encoded, as: UTF8.self)
                }
                .joined(separator: ",")

            reportNavigation(path: "[\(pathStr)]")
        } catch {
            reportNavigation(path: unencodablePath)
        }
    }

    func reportNavigation(path: Any) {
        reportNavigation(path: unencodablePath)
    }

}

extension View {
    @available(iOS 16.0, macOS 12.0, *)
    public func instrumentNavigation(path: NavigationPath) -> some View {
        HoneycombNavigationProcessor.shared.reportNavigation(path: path)

        return modifier(EmptyModifier())
    }

    public func instrumentNavigation(path: Encodable) -> some View {
        HoneycombNavigationProcessor.shared.reportNavigation(path: path)

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
        if HoneycombNavigationProcessor.shared.currentNavigationPath != nil {
            span.setAttribute(
                key: "screen.name",
                value: HoneycombNavigationProcessor.shared.currentNavigationPath!
            )

        }
    }

    public func onEnd(span: any ReadableSpan) {}

    public func shutdown(explicitTimeout: TimeInterval? = nil) {}

    public func forceFlush(timeout: TimeInterval? = nil) {}
}
