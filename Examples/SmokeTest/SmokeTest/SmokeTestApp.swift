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
                .setDebug(true)
                .setSessionTimeout(10)
                .setSpanProcessor(SampleSpanProcessor())
                .setTouchInstrumentationEnabled(true)
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
