import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Rewrites a log record into the shape Honeycomb has always emitted, or drops it (returns `nil`).
///
/// Unlike the web SDK, a Swift `LogRecordProcessor` is a chain, not a list of siblings: it receives
/// a copy of the record and decides what the next processor sees. That means a shaper can drop a
/// record, and it can rebuild the record completely, including its instrumentation scope.
public typealias LogRecordShaper = @Sendable (ReadableLogRecord) -> ReadableLogRecord?

/// A `LogRecordProcessor` that applies `LogRecordShaper`s, then forwards to the next processor.
public final class ShapeLogRecordProcessor: LogRecordProcessor, @unchecked Sendable {
    private let next: LogRecordProcessor
    private let shapers: [LogRecordShaper]

    public init(next: LogRecordProcessor, shapers: [LogRecordShaper]) {
        self.next = next
        self.shapers = shapers
    }

    public func onEmit(logRecord: ReadableLogRecord) {
        var record: ReadableLogRecord? = logRecord
        for shaper in shapers {
            guard let current = record else { return }
            record = shaper(current)
        }
        if let record { next.onEmit(logRecord: record) }
    }

    public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        next.forceFlush(explicitTimeout: explicitTimeout)
    }

    public func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
        next.shutdown(explicitTimeout: explicitTimeout)
    }
}
