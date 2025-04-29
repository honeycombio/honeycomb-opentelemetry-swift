import Honeycomb
import SwiftUI

@main
struct SmokeTestApp: App {
    // @State private var session: HoneycombSession? = nil

    init() {
        /*
        NotificationCenter.default.addObserver(
            forName: .sessionStarted,
            object: nil,
            queue: .main
        ) { notification in
            guard let session = notification.userInfo?["session"] as? HoneycombSession else {
                return
            }
            self.session = session
        }
        */

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
