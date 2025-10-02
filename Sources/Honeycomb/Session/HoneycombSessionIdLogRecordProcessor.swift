import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

struct HoneycombSessionIdLogRecordProcessor: LogRecordProcessor {
    private var sessionManager: HoneycombSessionManager
    private var nextProcessor: LogRecordProcessor

    init(nextProcessor: LogRecordProcessor, sessionManager: HoneycombSessionManager) {
        self.nextProcessor = nextProcessor
        self.sessionManager = sessionManager
    }

    public func onEmit(logRecord: ReadableLogRecord) {
        var newAttributes = logRecord.attributes
        newAttributes["session.id"] = AttributeValue.string(sessionManager.session.id)

        let enhancedRecord = ReadableLogRecord(
            resource: logRecord.resource,
            instrumentationScopeInfo: logRecord.instrumentationScopeInfo,
            timestamp: logRecord.timestamp,
            observedTimestamp: logRecord.observedTimestamp,
            spanContext: logRecord.spanContext,
            severity: logRecord.severity,
            body: logRecord.body,
            attributes: newAttributes
        )

        nextProcessor.onEmit(logRecord: enhancedRecord)
    }

    public func shutdown(explicitTimeout: TimeInterval? = nil) -> ExportResult {
        return nextProcessor.shutdown(explicitTimeout: explicitTimeout)
    }

    public func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
        return nextProcessor.forceFlush(explicitTimeout: explicitTimeout)
    }
}
