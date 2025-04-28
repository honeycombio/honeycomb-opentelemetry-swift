#if canImport(UIKit) && !os(watchOS)
    import Foundation
    import OpenTelemetryApi
    import UIKit

    internal let honeycombUIKitInstrumentationName = "io.honeycomb.uikit"

    internal func getUIKitViewTracer() -> Tracer {
        return OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: honeycombUIKitInstrumentationName,
            instrumentationVersion: honeycombLibraryVersion
        )
    }

    public func installUINavigationInstrumentation() {
        UIViewController.swizzle()
    }
#endif
