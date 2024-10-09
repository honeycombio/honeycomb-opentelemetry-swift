import InMemoryExporter
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

    func testPropagation() {
        let processor = HoneycombBaggageSpanProcessor(filter: { (e) in return true })
        let exporter = InMemoryExporter()
        let simple = SimpleSpanProcessor(spanExporter: exporter)
        OpenTelemetry.registerTracerProvider(
            tracerProvider: TracerProviderBuilder().add(spanProcessor: processor)
                .add(spanProcessor: simple).build()
        )
        let tracer = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: "test",
            instrumentationVersion: "1.0.0"
        )

        if let key = EntryKey(name: "test-key") {
            if let value = EntryValue(string: "test-value") {
                let parent = tracer.spanBuilder(spanName: "parent").startSpan()
                let b = OpenTelemetry.instance.baggageManager.baggageBuilder()
                    .put(key: key, value: value, metadata: nil).build()
                OpenTelemetry.instance.contextProvider.setActiveBaggage(b)

                let child = tracer.spanBuilder(spanName: "child").startSpan()

                child.end()
                parent.end()
            }
        }

        simple.forceFlush()

        let spans = exporter.getFinishedSpanItems()
        XCTAssert(spans.count == 2)

        let child = spans.first(where: { s in return s.name == "child" })
        XCTAssert(child != nil)

        let parent = spans.first(where: { s in return s.name == "parent" })
        XCTAssert(parent != nil)

        XCTAssert(child?.attributes.count == 1)

        let attr = child?.attributes.first

        XCTAssert(attr?.key == "test-key")
        XCTAssert(attr?.value.description == "test-value")
    }
}
