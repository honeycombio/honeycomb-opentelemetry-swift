#if canImport(UIKit)
    import Foundation
    import OpenTelemetryApi
    import UIKit

    internal let honeycombUIKitInstrumentationName = "io.honeycomb.instrumentation.uikit"

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
