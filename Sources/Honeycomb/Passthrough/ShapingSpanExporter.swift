import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Rewrites a finished span into the shape Honeycomb has always emitted.
///
/// A `SpanProcessor` cannot change a span after it ends, and `SpanData` has no setter for the
/// instrumentation scope. So shaping happens in the exporter, on the immutable `SpanData`, and
/// anything that depends on the scope name must be fixed where the tracer is configured.
public typealias SpanShaper = @Sendable (SpanData) -> SpanData

/// A `SpanExporter` decorator that applies `SpanShaper`s before handing spans to the real exporter.
///
/// Wrap the exporter that sits closest to the `BatchSpanProcessor`, outside any persistence
/// decorator, so that spans are cached already shaped.
public final class ShapingSpanExporter: SpanExporter, @unchecked Sendable {
    private let inner: SpanExporter
    private let shapers: [SpanShaper]

    public init(inner: SpanExporter, shapers: [SpanShaper]) {
        self.inner = inner
        self.shapers = shapers
    }

    private func shape(_ spans: [SpanData]) -> [SpanData] {
        spans.map { span in shapers.reduce(span) { $1($0) } }
    }

    public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode
    {
        inner.export(spans: shape(spans), explicitTimeout: explicitTimeout)
    }

    public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        inner.flush(explicitTimeout: explicitTimeout)
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        inner.shutdown(explicitTimeout: explicitTimeout)
    }

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func export(spans: [SpanData], explicitTimeout: TimeInterval?) async
        -> SpanExporterResultCode
    {
        await inner.export(spans: shape(spans), explicitTimeout: explicitTimeout)
    }

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func flush(explicitTimeout: TimeInterval?) async -> SpanExporterResultCode {
        await inner.flush(explicitTimeout: explicitTimeout)
    }

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func shutdown(explicitTimeout: TimeInterval?) async {
        await inner.shutdown(explicitTimeout: explicitTimeout)
    }
}
