import Foundation
import OpenTelemetryApi

private let errorLoggerInstrumentationName = "@honeycombio/instrumentation-error-logger"

class HoneycombErrorLogger {
    private static let defaultErrorLogger = OpenTelemetry.instance.loggerProvider.get(
        instrumentationScopeName: errorLoggerInstrumentationName
    )
    
    protocol AttributeValueConvertable {
        func attributeValue() -> AttributeValue
    }
    
    static func logError(
        error: Error,
        callstack: [String] = Thread.callStackSymbols,
        attributes: [String: AttributeValue] = [:],
        logger: Logger = defaultErrorLogger,
        using closure: (Error) -> [String: AttributeValueConvertable]
    ) {
        let timestamp = Date()
        let type = String( describing: Mirror(reflecting: error).subjectType)
        let message = error.localizedDescription
        
        var errorAttributes = [
            "exception.type": type.attributeValue(),
            "exception.message": message.attributeValue(),
            "exception.stacktrace": AttributeValue(callstack)
        ].merging(attributes, uniquingKeysWith: {(_, last) in last})
        
        for (key, value) in closure(error) {
            errorAttributes[key] = value.attributeValue()
        }
        
        logError("", errorAttributes, logger, timestamp)
    }

    static func logError(
        _ namespace: String,
        _ attributes: [String: AttributeValue],
        _ logger: Logger = defaultErrorLogger,
        _ timestamp: Date = Date()
    ) {
        var logAttrs: [String: AttributeValue] = [
            "name": namespace.attributeValue()
        ]
        for (key, value) in attributes {
            let namespacedKey = "\(namespace).\(key)"
            logAttrs[namespacedKey] = value
        }
        
        logger.logRecordBuilder()
            .setTimestamp(timestamp)
            .setObservedTimestamp(Date())
            .setAttributes(logAttrs)
            .emit()
    }
    
}


