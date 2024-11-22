import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

private let NavigationInstrumentationName = "@honeycombio/instrumentation-navigation"
private let NavigationSpanName = "Navigation"
private let UnencodablePath = "<unencodable path>"

private func activeBaggage() -> Baggage? {
    return OpenTelemetry.instance.contextProvider.activeBaggage
}

func getTracer() -> Tracer {
    return OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: NavigationInstrumentationName,
        instrumentationVersion: honeycombLibraryVersion
    )
}

@available(iOS 16.0, macOS 12.0, *)
func reportNavigation(path: NavigationPath) {
    if let codablePath = path.codable {
        reportNavigation(path: codablePath)
    } else {
        reportNavigation(path: UnencodablePath)
    }

}

var currentNavigationPath: String? = nil

func reportNavigation(path: Encodable) {
    do {
        let encoder = JSONEncoder()
        let data = try encoder.encode(path)
        let pathStr = String(decoding: data, as: UTF8.self)
        print("current path: \(pathStr)")

        currentNavigationPath = pathStr

        // emit a span that says we've navigated to this path
        getTracer().spanBuilder(spanName: NavigationSpanName)
            .setAttribute(key: "NavigationPath", value: pathStr)
            .startSpan()
            .end()
    } catch {
        // Handle error
    }
}

func reportNavigation(path: Any) {
    reportNavigation(path: UnencodablePath)
}

extension View {
    @available(iOS 16.0, macOS 12.0, *)
    func instrumentNavigations(path: NavigationPath) -> some View {
        reportNavigation(path: path)

        return modifier(EmptyModifier())
    }

    func instrumentNavigations(path: Encodable) -> some View {
        reportNavigation(path: path)

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
        if currentNavigationPath != nil {
            span.setAttribute(key: "CurrentNavigationPath", value: currentNavigationPath!)

        }
    }

    public func onEnd(span: any ReadableSpan) {}

    public func shutdown(explicitTimeout: TimeInterval? = nil) {}

    public func forceFlush(timeout: TimeInterval? = nil) {}
}
