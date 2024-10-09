import InMemoryExporter
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import Honeycomb

class HoneycombBaggageSpanProcessorTests: XCTestCase {
    let readableSpan = ReadableSpanMock()

    func testNoCrash() {
        let processor = HoneycombBaggageSpanProcessor(filter: { _ in true })
        processor.onStart(parentContext: nil, span: readableSpan)
        XCTAssertTrue(processor.isStartRequired)
        processor.onEnd(span: readableSpan)
        XCTAssertFalse(processor.isEndRequired)
        processor.forceFlush()
        processor.shutdown()
    }

    func testFiltering() {
        guard let key = EntryKey(name: "test-key") else {
            XCTFail("cannot create entry key")
            return
        }

        guard let keep = EntryKey(name: "keepme") else {
            XCTFail("cannot create entry key")
            return
        }

        guard let value = EntryValue(string: "test-value") else {
            XCTFail("cannot create entry value")
            return
        }

        let b = OpenTelemetry.instance.baggageManager.baggageBuilder()
            .put(key: key, value: value, metadata: nil)
            .put(key: keep, value: value, metadata: nil)
            .build()
        let processor = HoneycombBaggageSpanProcessor(
            filter: { $0.key.name == "keepme" },
            activeBaggage: { b }
        )

        processor.onStart(parentContext: nil, span: readableSpan)

        XCTAssertEqual(readableSpan.attributes.count, 1)
        XCTAssertTrue(readableSpan.attributes.contains(where: { $0.key == "keepme" }))
    }

    func testPropagation() {
        let processor = HoneycombBaggageSpanProcessor(filter: { _ in true })
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

        guard let key = EntryKey(name: "test-key") else {
            XCTFail()
            return
        }

        guard let value = EntryValue(string: "test-value") else {
            XCTFail()
            return
        }

        let parent = tracer.spanBuilder(spanName: "parent").startSpan()
        let b = OpenTelemetry.instance.baggageManager.baggageBuilder()
            .put(key: key, value: value, metadata: nil).build()
        OpenTelemetry.instance.contextProvider.setActiveBaggage(b)

        let child = tracer.spanBuilder(spanName: "child").startSpan()

        child.end()
        parent.end()

        simple.forceFlush()

        let spans = exporter.getFinishedSpanItems()
        XCTAssertEqual(spans.count, 2)

        guard let pChild = spans.first(where: { $0.name == "child" }) else {
            XCTFail("failed to find child span")
            return
        }

        XCTAssertTrue(spans.contains(where: { $0.name == "parent" }))

        XCTAssertEqual(pChild.attributes.count, 1)

        guard let attr = pChild.attributes.first else {
            XCTFail("failed to get span attributes")
            return
        }

        XCTAssertEqual(attr.key, "test-key")
        XCTAssertEqual(attr.value.description, "test-value")
    }
}
