
import XCTest

@testable import Honeycomb

import OpenTelemetryApi
import OpenTelemetrySdk

final class HoneycombSmokeTests: XCTestCase {
    override class func setUp() {
        do {
            let options = try HoneycombOptions.Builder()
                .setAPIKey("test-key")
                .setApiEndpoint("http://localhost:4318")
                .setDebug(true)
                .build()
            try Honeycomb.configure(options: options)
        } catch {
            NSException(name: NSExceptionName("HoneycombOptionsError"), reason: "\(error)").raise()
        }
    }
    
    override class func tearDown() {
        let tracerProvider = OpenTelemetry.instance.tracerProvider as! TracerProviderSdk
        tracerProvider.forceFlush()
        tracerProvider.shutdown()
        Thread.sleep(forTimeInterval: 5.0)
    }

    func testSimpleSpan() throws {
        let tracerProvider = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: "@honeycombio/smoke-test",
            instrumentationVersion: nil)
        let span = tracerProvider.spanBuilder(spanName: "test-span").startSpan()
        span.end()
    }
}
 
