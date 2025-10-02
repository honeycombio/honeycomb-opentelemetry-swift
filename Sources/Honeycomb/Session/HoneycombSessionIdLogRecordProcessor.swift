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
        var enhancedRecord = logRecord

        enhancedRecord.setAttribute(
            key: SemanticConventions.Session.id,
            value: sessionManager.sessionId
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
