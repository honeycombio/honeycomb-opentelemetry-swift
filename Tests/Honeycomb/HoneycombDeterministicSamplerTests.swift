import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import Honeycomb

class HoneycombDeterministicSamplerTests: XCTestCase {
    func testSampler() {
        let testCases = [
            (rate: 0, sampled: false),
            (rate: 1, sampled: true),
            (rate: 10, sampled: true),
            (rate: 100, sampled: true),
        ]

        // static trace id to ensure the inner traceIdRatio
        // sampler always samples.
        let traceID = TraceId.init(idHi: 10, idLo: 10)
        let spanID = SpanId.random()
        let parentContext = SpanContext.create(
            traceId: traceID,
            spanId: spanID,
            traceFlags: TraceFlags.init(),
            traceState: TraceState.init()
        )

        for (rate, sampled) in testCases {
            XCTContext.runActivity(
                named: "",
                block: { activity in
                    let sampler = HoneycombDeterministicSampler(sampleRate: rate)
                    let result = sampler.shouldSample(
                        parentContext: parentContext,
                        traceId: traceID,
                        name: "test",
                        kind: SpanKind.client,
                        attributes: [:],
                        parentLinks: []
                    )
                    XCTAssertEqual(result.isSampled, sampled)

                    if sampled {
                        guard let r = result.attributes["SampleRate"] else {
                            XCTFail("sample rate attribute not found")
                            return
                        }
                        XCTAssertEqual(AttributeValue.int(rate), r)
                    }
                }
            )
        }
    }
}
