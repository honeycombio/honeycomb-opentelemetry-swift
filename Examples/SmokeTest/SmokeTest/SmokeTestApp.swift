import Honeycomb
import SwiftUI

@main
struct SmokeTestApp: App {
    init() {
        do {
            let options = try HoneycombOptions.Builder()
                .setAPIKey("test-key")
                .setAPIEndpoint("http://localhost:4318")
                .setServiceName("ios-test")
                .setServiceVersion("0.0.1")
                .setDebug(true)
                .setSessionTimeout(10)
                .setSpanProcessor(SampleSpanProcessor())
                .setTouchInstrumentationEnabled(true)
                // The network smoke tests check that this request gets no span.
                .setURLSessionRequestFilter { $0.url?.path != "/filtered-api" }
                // Only these paths are renamed, so that the other requests keep the default name
                // (the HTTP method) that the rest of the network smoke tests look for.
                .setURLSessionSpanNameProvider { request in
                    guard let path = request.url?.path else {
                        return nil
                    }
                    if path.hasPrefix("/named-api/") {
                        return "GET /named-api/:id"
                    }
                    if path == "/error-api" {
                        return "GET /error-api"
                    }
                    return nil
                }
                .build()
            try Honeycomb.configure(options: options)
        } catch {
            NSException(name: NSExceptionName("HoneycombOptionsError"), reason: "\(error)").raise()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
