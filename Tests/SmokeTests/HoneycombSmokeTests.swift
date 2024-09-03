import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import Honeycomb

final class HoneycombSmokeTests: XCTestCase {
    override class func setUp() {
        do {
            let options = try HoneycombOptions.Builder()
                .setAPIKey("test-key")
                .setApiEndpoint("http://localhost:4318")
                .setServiceName("swift-test")
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
        // tracerProvider.forceFlush() starts an async http operation, and holds only a weak
        // reference to itself. So, if the test quits immediately, the whole thing will be
        // garbage-collected and the http request will never be sent. Until that behavior is
        // fixed, it's necessary to sleep here, to allow the outstanding HTTP requests to be
        // processed.
        Thread.sleep(forTimeInterval: 5.0)
    }

    func testSimpleSpan() throws {
        let tracerProvider = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: "@honeycombio/smoke-test",
            instrumentationVersion: nil
        )
        let span = tracerProvider.spanBuilder(spanName: "test-span").startSpan()
        span.end()
    }

    func testMetricKit() throws {
        reportMetrics(payload: FakeMetricPayload())
        if #available(iOS 14.0, *) {
            reportDiagnostics(payload: FakeDiagnosticPayload())
        }
    }
}
