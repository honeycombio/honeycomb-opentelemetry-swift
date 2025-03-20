import BaggagePropagationProcessor
import Foundation
import GRPC
import MetricKit
import NIO
import NetworkStatus
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetryProtocolExporterGrpc
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk
import ResourceExtension
import StdoutExporter
import SwiftUI

private func createAttributeDict(_ dict: [String: String]) -> [String: AttributeValue] {
    var result: [String: AttributeValue] = [:]
    for (key, value) in dict {
        result[key] = AttributeValue(value)
    }
    return result
}

private func createKeyValueList(_ dict: [String: String]) -> [(String, String)] {
    var result: [(String, String)] = []
    for (key, value) in dict {
        result.append((key, value))
    }
    return result
}

public class Honeycomb {
    @available(iOS 13.0, macOS 12.0, *)
    static private let metricKitSubscriber = MetricKitSubscriber()

    static public func configure(options: HoneycombOptions) throws {

        if options.debug {
            configureDebug(options: options)
        }

        guard let tracesEndpoint = URL(string: options.tracesEndpoint) else {
            throw HoneycombOptionsError.malformedURL(options.tracesEndpoint)
        }
        guard let metricsEndpoint = URL(string: options.metricsEndpoint) else {
            throw HoneycombOptionsError.malformedURL(options.metricsEndpoint)
        }
        guard let logsEndpoint = URL(string: options.logsEndpoint) else {
            throw HoneycombOptionsError.malformedURL(options.logsEndpoint)
        }

        let otlpTracesConfig = OtlpConfiguration(
            timeout: options.tracesTimeout,
            headers: createKeyValueList(options.tracesHeaders)
        )
        let otlpMetricsConfig = OtlpConfiguration(
            timeout: options.metricsTimeout,
            headers: createKeyValueList(options.metricsHeaders)
        )
        let otlpLogsConfig = OtlpConfiguration(
            timeout: options.logsTimeout,
            headers: createKeyValueList(options.logsHeaders)
        )

        let resource = DefaultResources().get()
            .merging(other: Resource(attributes: createAttributeDict(options.resourceAttributes)))

        // Traces

        var traceExporter: SpanExporter
        if options.tracesProtocol == .grpc {
            // Break down the URL into host and port, or use defaults from the spec.
            let host = tracesEndpoint.host ?? "api.honeycomb.io"
            let port = tracesEndpoint.port ?? 4317

            let channel =
                ClientConnection.usingPlatformAppropriateTLS(
                    for: MultiThreadedEventLoopGroup(numberOfThreads: 1)
                )
                .connect(host: host, port: port)

            traceExporter = OtlpTraceExporter(channel: channel, config: otlpTracesConfig)
        } else if options.tracesProtocol == .httpJSON {
            throw HoneycombOptionsError.unsupportedProtocol("http/json")
        } else {
            traceExporter = OtlpHttpTraceExporter(
                endpoint: tracesEndpoint,
                config: otlpTracesConfig
            )
        }

        var spanExporter =
            if options.debug {
                MultiSpanExporter(spanExporters: [traceExporter, StdoutSpanExporter()])
            } else {
                traceExporter
            }

        if options.offlineCachingEnabled {
            spanExporter = createPersistenceSpanExporter(spanExporter)
        }

        let spanProcessor = CompositeSpanProcessor()
        spanProcessor.addSpanProcessor(BatchSpanProcessor(spanExporter: spanExporter))

        #if canImport(UIKit)
            spanProcessor.addSpanProcessor(
                UIDeviceSpanProcessor()
            )
        #endif

        if let clientSpanProcessor = options.spanProcessor {
            spanProcessor.addSpanProcessor(clientSpanProcessor)
        }

        let baggageSpanProcessor = BaggagePropagationProcessor(filter: { _ in true })

        var tracerProviderBuilder = TracerProviderBuilder()
            .add(spanProcessor: spanProcessor)
            .add(spanProcessor: baggageSpanProcessor)
            .add(spanProcessor: HoneycombNavigationPathSpanProcessor())
            .add(
                spanProcessor: HoneycombSessionIdSpanProcessor(
                    debug: options.debug,
                    sessionLifetimeSeconds: options.sessionTimeout
                )
            )

        do {
            let networkMonitor = try NetworkMonitor()
            tracerProviderBuilder =
                tracerProviderBuilder
                .add(spanProcessor: NetworkStatusSpanProcessor(monitor: networkMonitor))
        } catch {
            NSLog("Unable to create NetworkMonitor: \(error)")
        }

        let tracerProvider =
            tracerProviderBuilder
            .with(resource: resource)
            .with(sampler: HoneycombDeterministicSampler(sampleRate: options.sampleRate))
            .build()

        // Metrics

        var metricExporter: MetricExporter
        if options.metricsProtocol == .grpc {
            // Break down the URL into host and port, or use defaults from the spec.
            let host = metricsEndpoint.host ?? "api.honeycomb.io"
            let port = metricsEndpoint.port ?? 4317

            let channel =
                ClientConnection.usingPlatformAppropriateTLS(
                    for: MultiThreadedEventLoopGroup(numberOfThreads: 1)
                )
                .connect(host: host, port: port)

            metricExporter = OtlpMetricExporter(channel: channel, config: otlpMetricsConfig)
        } else if options.metricsProtocol == .httpJSON {
            throw HoneycombOptionsError.unsupportedProtocol("http/json")
        } else {
            metricExporter = OtlpHttpMetricExporter(
                endpoint: metricsEndpoint,
                config: otlpMetricsConfig
            )
        }

        if options.offlineCachingEnabled {
            metricExporter = createPersistenceMetricExporter(metricExporter)
        }

        let meterProvider = MeterProviderBuilder()
            .with(processor: MetricProcessorSdk())
            .with(exporter: metricExporter)
            .with(resource: Resource())
            .build()

        // Logs

        var logExporter: LogRecordExporter
        if options.logsProtocol == .grpc {
            // Break down the URL into host and port, or use defaults from the spec.
            let host = logsEndpoint.host ?? "api.honeycomb.io"
            let port = logsEndpoint.port ?? 4317

            let channel =
                ClientConnection.usingPlatformAppropriateTLS(
                    for: MultiThreadedEventLoopGroup(numberOfThreads: 1)
                )
                .connect(host: host, port: port)

            logExporter = OtlpLogExporter(channel: channel, config: otlpLogsConfig)
        } else if options.logsProtocol == .httpJSON {
            throw HoneycombOptionsError.unsupportedProtocol("http/json")
        } else {
            logExporter = OtlpHttpLogExporter(endpoint: logsEndpoint, config: otlpLogsConfig)
        }

        let logProcessor = SimpleLogRecordProcessor(logRecordExporter: logExporter)

        let loggerProvider = LoggerProviderBuilder()
            .with(processors: [logProcessor])
            .with(resource: resource)
            .build()

        // Register everything at once, so that we don't leave OTel partially initialized.

        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
        OpenTelemetry.registerMeterProvider(meterProvider: meterProvider)
        OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)

        if options.urlSessionInstrumentationEnabled {
            installNetworkInstrumentation(options: options)
        }
        #if canImport(UIKit)
            if options.uiKitInstrumentationEnabled {
                installUINavigationInstrumentation()
            }
            if options.touchInstrumentationEnabled {
                installWindowInstrumentation()
            }
        #endif
        if options.unhandledExceptionInstrumentationEnabled {
            HoneycombUncaughtExceptionHandler.initializeUnhandledExceptionInstrumentation()
        }

        if #available(iOS 13.0, macOS 12.0, *) {
            if options.metricKitInstrumentationEnabled {
                MXMetricManager.shared.add(self.metricKitSubscriber)
            }
        }
    }

    private static let errorLoggerInstrumentationName = "io.honeycomb.error"

    public static func getDefaultErrorLogger() -> OpenTelemetryApi.Logger {
        return OpenTelemetry.instance.loggerProvider.get(
            instrumentationScopeName: errorLoggerInstrumentationName
        )
    }

    /// Logs an `NSError`. This can be used for logging any caught exceptions in your own code that will not be logged by our crash instrumentation.
    /// - Parameters:
    ///   - error: The `NSError` itself
    ///   - attributes: Additional attributes you would like to log along with the default ones provided.
    ///   - thread: Thread where the error occurred. Add this to include additional attributes related to the thread
    ///   - logger: Defaults to the Honeycomb error `Logger`. Provide if you want to use a different OpenTelemetry `Logger`
    public static func log(
        error: NSError,
        attributes: [String: AttributeValue] = [:],
        thread: Thread?,
        logger: OpenTelemetryApi.Logger = getDefaultErrorLogger()
    ) {
        let timestamp = Date()
        let type = String(describing: Mirror(reflecting: error).subjectType)
        let code = error.code
        let message = error.localizedDescription

        var errorAttributes = [
            "exception.type": type.attributeValue(),
            "exception.message": message.attributeValue(),
            "exception.code": code.attributeValue(),
        ]
        .merging(attributes, uniquingKeysWith: { (_, last) in last })

        if let name = thread?.name {
            errorAttributes["thread.name"] = name.attributeValue()
        }

        logError(errorAttributes, logger, timestamp)
    }

    /// Logs an `NSException`. This can be used for logging any caught exceptions in your own code that will not be logged by our crash instrumentation.
    /// - Parameters:
    ///   - exception: The `NSException` itself
    ///   - attributes: Additional attributes you would like to log along with the default ones provided.
    ///   - thread: Thread where the exception occurred. Add this to include additional attributes related to the thread
    ///   - logger: Defaults to the Honeycomb error `Logger`. Provide if you want to use a different OpenTelemetry `Logger`
    public static func log(
        exception: NSException,
        attributes: [String: AttributeValue] = [:],
        thread: Thread?,
        logger: OpenTelemetryApi.Logger = getDefaultErrorLogger()
    ) {
        let timestamp = Date()
        let type = String(describing: Mirror(reflecting: exception).subjectType)
        let message = exception.reason ?? exception.name.rawValue

        var errorAttributes = [
            "exception.type": type.attributeValue(),
            "exception.message": message.attributeValue(),
            "exception.name": exception.name.rawValue.attributeValue(),
            "exception.stacktrace": exception.callStackSymbols.joined(separator: "\n")
                .attributeValue(),
        ]
        .merging(attributes, uniquingKeysWith: { (_, last) in last })

        if let name = thread?.name {
            errorAttributes["thread.name"] = name.attributeValue()
        }

        logError(errorAttributes, logger, timestamp)
    }

    /// Logs an `Error`. This can be used for logging any caught exceptions in your own code that will not be logged by our crash instrumentation.
    /// - Parameters:
    ///   - error: The `Error` itself
    ///   - attributes: Additional attributes you would like to log along with the default ones provided.
    ///   - thread: Thread where the error occurred. Add this to include additional attributes related to the thread
    ///   - logger: Defaults to the Honeycomb error `Logger`. Provide if you want to use a different OpenTelemetry `Logger`
    public static func log(
        error: Error,
        attributes: [String: AttributeValue] = [:],
        thread: Thread?,
        logger: OpenTelemetryApi.Logger = getDefaultErrorLogger()
    ) {
        let timestamp = Date()
        let type = String(describing: Mirror(reflecting: error).subjectType)
        let message = error.localizedDescription

        var errorAttributes = [
            "exception.type": type.attributeValue(),
            "exception.message": message.attributeValue(),
        ]
        .merging(attributes, uniquingKeysWith: { (_, last) in last })

        if let name = thread?.name {
            errorAttributes["thread.name"] = name.attributeValue()
        }

        logError(errorAttributes, logger, timestamp)
    }

    private static func logError(
        _ attributes: [String: AttributeValue],
        _ logger: OpenTelemetryApi.Logger = getDefaultErrorLogger(),
        _ timestamp: Date = Date()
    ) {
        var logAttrs: [String: AttributeValue] = [:]
        for (key, value) in attributes {
            logAttrs[key] = value
        }

        logger.logRecordBuilder()
            .setTimestamp(timestamp)
            .setAttributes(logAttrs)
            .setSeverity(.fatal)
            .emit()
    }

    @available(iOS 16.0, macOS 13.0, *)
    public static func setCurrentScreen(path: NavigationPath) {
        HoneycombNavigationProcessor.shared.reportNavigation(path: path)
    }
    public static func setCurrentScreen(path: String) {
        HoneycombNavigationProcessor.shared.reportNavigation(path: path)
    }
    public static func setCurrentScreen(path: Encodable) {
        HoneycombNavigationProcessor.shared.reportNavigation(path: path)
    }
    public static func setCurrentScreen(path: [Encodable]) {
        HoneycombNavigationProcessor.shared.reportNavigation(path: path)
    }
    public static func setCurrentScreen(path: Any) {
        HoneycombNavigationProcessor.shared.reportNavigation(path: path)
    }
}
