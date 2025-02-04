import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

class HoneycombDeterministicSampler: Sampler {
    private let inner: Sampler
    private let rate: [String: AttributeValue]

    init(sampleRate: Int) {
        var inner: Sampler

        switch sampleRate {
        case Int.min..<1:
            print("Sample rate too low, not emitting any spans!")
            inner = Samplers.alwaysOff
        case 1:
            print("Not sampling, emitting all spans")
            inner = Samplers.alwaysOn
        default:
            print("Sampling enabled: emitting every 1 in \(sampleRate) spans")
            inner = Samplers.traceIdRatio(ratio: 1.0 / Double(sampleRate))
        }

        self.inner = inner
        self.rate = ["SampleRate": AttributeValue(sampleRate)]
    }

    func shouldSample(
        parentContext: SpanContext?,
        traceId: TraceId,
        name: String,
        kind: SpanKind,
        attributes: [String: AttributeValue],
        parentLinks: [SpanData.Link]
    ) -> any Decision {
        var result = self.inner.shouldSample(
            parentContext: parentContext,
            traceId: traceId,
            name: name,
            kind: kind,
            attributes: attributes,
            parentLinks: parentLinks
        )

        if result.isSampled {
            let attrs = result.attributes.merging(
                rate,
                uniquingKeysWith: { (_, new) in new }
            )
            result = HoneycombDecision(isSampled: result.isSampled, attributes: attrs)
        }

        return result
    }

    var description: String = "DeterministicSampler"
}

private struct HoneycombDecision: Decision {
    let isSampled: Bool

    let attributes: [String: AttributeValue]
}
