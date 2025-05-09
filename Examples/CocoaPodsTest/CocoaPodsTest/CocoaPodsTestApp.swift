import Honeycomb
import SwiftUI

@main
struct CocoaPodsTestApp: App {
    init() {
        do {
            let options = try HoneycombOptions.Builder()
                .setAPIKey("test-key")
                .setAPIEndpoint("http://localhost:4318")
                .setServiceName("ios-test")
                .setServiceVersion("0.0.1")
                .setDebug(true)
                .setSessionTimeout(10)
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
