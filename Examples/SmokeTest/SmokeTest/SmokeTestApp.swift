import Honeycomb
import SwiftUI
import UIKit

@main
struct SmokeTestApp: App {
    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true

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
