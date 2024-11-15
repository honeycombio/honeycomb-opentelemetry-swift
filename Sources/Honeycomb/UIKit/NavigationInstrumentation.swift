#if canImport(UIKit)
    import Foundation
    import OpenTelemetryApi
    import UIKit

    private let honeycombInstrumentationView = "@honeycombio/instrumented-view"

    public func InstallUINavigationInstrumentation() {
        UIViewController.swizzle()
    }

    internal func getViewTracer() -> Tracer {
        return OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: honeycombInstrumentationView,
            instrumentationVersion: honeycombLibraryVersion
        )
    }
#endif
