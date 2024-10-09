import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import Honeycomb

class HoneycombBaggageSpanProcessorTests: XCTestCase {
    let readableSpan = ReadableSpanMock()

    func testNoCrash() {
        let processor = HoneycombBaggageSpanProcessor(filter: { (e) in return true })
        processor.onStart(parentContext: nil, span: readableSpan)
        XCTAssertTrue(processor.isStartRequired)
        processor.onEnd(span: readableSpan)
        XCTAssertFalse(processor.isEndRequired)
        processor.forceFlush()
        processor.shutdown()
    }
}
