import Foundation
import OpenTelemetryApi

private let honeycombInstrumentationView = "@honeycombio/instrumented-view";

public class UINavigationAutoInstrumentation {
    public init(configuration: HoneycombOptions) {
        
    }
}

func getViewTracer() -> Tracer {
    return OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: honeycombInstrumentationView, 
        instrumentationVersion: honeycombLibraryVersion
    )
}