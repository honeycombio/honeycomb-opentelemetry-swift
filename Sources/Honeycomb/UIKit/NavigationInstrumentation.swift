#if canImport(UIKit)
    import Foundation
    import OpenTelemetryApi
    import UIKit

    internal let honeycombUIKitInstrumentationName = "@honeycombio/instrumentation-uikit"

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
