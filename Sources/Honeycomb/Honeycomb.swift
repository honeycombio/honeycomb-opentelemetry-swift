import BaggagePropagationProcessor
import Foundation
import NetworkStatus
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk
import ResourceExtension
import StdoutExporter
import SwiftUI

#if canImport(MetricKit)
    import MetricKit
#endif

#if canImport(OpenTelemetryProtocolExporterGrpc)
    import GRPC
    import NIO
    import OpenTelemetryProtocolExporterGrpc
#endif

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
    static private var sessionManager: HoneycombSessionManager? = nil
    /// The OpenTelemetry Resource containing service information, custom attributes, and telemetry metadata.
    ///
    /// This property initially returns the default OpenTelemetry resource with system information.
    /// After calling `configure(options:)`, it returns the fully configured resource including
    /// custom resource attributes and service configuration.
    ///
    /// Use this property to inspect resource attributes for debugging or validation purposes:
    /// ```swift
    /// let resource = Honeycomb.resource
    /// print("Service name: \(resource.attributes["service.name"]?.description ?? "unknown")")
    /// ```
    public private(set) static var resource: Resource = DefaultResources().get()

    #if canImport(MetricKit) && !os(tvOS) && !os(macOS)
        static private let metricKitSubscriber = MetricKitSubscriber()
    #endif

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

        resource = DefaultResources().get()
            .merging(other: Resource(attributes: createAttributeDict(options.resourceAttributes)))
            .merging(other: Resource(attributes: createAttributeDict(getAppResources())))

        // Traces

        var traceExporter: SpanExporter
        if options.tracesProtocol == .grpc {
            #if canImport(OpenTelemetryProtocolExporterGrpc)
                // Break down the URL into host and port, or use defaults from the spec.
                let host = tracesEndpoint.host ?? "api.honeycomb.io"
                let port = tracesEndpoint.port ?? 4317

                let channel =
                    ClientConnection.usingPlatformAppropriateTLS(
                        for: MultiThreadedEventLoopGroup(numberOfThreads: 1)
                    )
                    .connect(host: host, port: port)

                traceExporter = OtlpTraceExporter(channel: channel, config: otlpTracesConfig)
            #else
                throw HoneycombOptionsError.unsupportedProtocol("gRPC")
            #endif
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

        #if canImport(UIKit) && !os(watchOS)
            spanProcessor.addSpanProcessor(
                UIDeviceSpanProcessor()
            )
        #endif

        if let clientSpanProcessor = options.spanProcessor {
            spanProcessor.addSpanProcessor(clientSpanProcessor)
        }

        let baggageSpanProcessor = BaggagePropagationProcessor(filter: { _ in true })

        sessionManager = HoneycombSessionManager(
            debug: options.debug,
            sessionLifetimeSeconds: options.sessionTimeout
        )

        var tracerProviderBuilder = TracerProviderBuilder()
            .add(spanProcessor: spanProcessor)
            .add(spanProcessor: baggageSpanProcessor)
            .add(spanProcessor: HoneycombNavigationPathSpanProcessor())
            .add(spanProcessor: HoneycombSessionIdSpanProcessor(sessionManager: sessionManager!))

        #if os(iOS) && !targetEnvironment(macCatalyst)
            do {
                let networkMonitor = try NetworkMonitor()
                tracerProviderBuilder =
                    tracerProviderBuilder
                    .add(spanProcessor: NetworkStatusSpanProcessor(monitor: networkMonitor))
            } catch {
                NSLog("Unable to create NetworkMonitor: \(error)")
            }
        #endif

        let tracerProvider =
            tracerProviderBuilder
            .with(resource: resource)
            .with(sampler: HoneycombDeterministicSampler(sampleRate: options.sampleRate))
            .build()

        // Metrics

        var metricExporter: MetricExporter
        if options.metricsProtocol == .grpc {
            #if canImport(OpenTelemetryProtocolExporterGrpc)
                // Break down the URL into host and port, or use defaults from the spec.
                let host = metricsEndpoint.host ?? "api.honeycomb.io"
                let port = metricsEndpoint.port ?? 4317

                let channel =
                    ClientConnection.usingPlatformAppropriateTLS(
                        for: MultiThreadedEventLoopGroup(numberOfThreads: 1)
                    )
                    .connect(host: host, port: port)

                metricExporter = OtlpMetricExporter(
                    channel: channel,
                    config: otlpMetricsConfig
                )
            #else
                throw HoneycombOptionsError.unsupportedProtocol("gRPC")
            #endif
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

        let metricReader = PeriodicMetricReaderBuilder(exporter: metricExporter).build()
        let meterProvider = MeterProviderSdk.builder()
            .registerMetricReader(reader: metricReader)
            .setResource(resource: resource)
            .build()

        // Logs

        var logExporter: LogRecordExporter
        if options.logsProtocol == .grpc {
            #if canImport(OpenTelemetryProtocolExporterGrpc)
                // Break down the URL into host and port, or use defaults from the spec.
                let host = logsEndpoint.host ?? "api.honeycomb.io"
                let port = logsEndpoint.port ?? 4317

                let channel =
                    ClientConnection.usingPlatformAppropriateTLS(
                        for: MultiThreadedEventLoopGroup(numberOfThreads: 1)
                    )
                    .connect(host: host, port: port)

                logExporter = OtlpLogExporter(channel: channel, config: otlpLogsConfig)
            #else
                throw HoneycombOptionsError.unsupportedProtocol("gRPC")
            #endif
        } else if options.logsProtocol == .httpJSON {
            throw HoneycombOptionsError.unsupportedProtocol("http/json")
        } else {
            logExporter = OtlpHttpLogExporter(endpoint: logsEndpoint, config: otlpLogsConfig)
        }

        let logProcessor = SimpleLogRecordProcessor(logRecordExporter: logExporter)
        let sessionLogProcessor = HoneycombSessionIdLogRecordProcessor(
            nextProcessor: logProcessor,
            sessionManager: sessionManager!
        )

        let loggerProvider = LoggerProviderBuilder()
            .with(processors: [sessionLogProcessor])
            .with(resource: resource)
            .build()

        // Register everything at once, so that we don't leave OTel partially initialized.

        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
        OpenTelemetry.registerMeterProvider(meterProvider: meterProvider)
        OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)

        if options.urlSessionInstrumentationEnabled {
            installNetworkInstrumentation(options: options)
        }
        #if canImport(UIKit) && !os(watchOS)
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

        #if canImport(MetricKit) && !os(tvOS) && !os(macOS)
            if #available(iOS 13.0, *) {
                if options.metricKitInstrumentationEnabled {
                    MXMetricManager.shared.add(self.metricKitSubscriber)
                }
            }
        #endif
    }

    public static func currentSession() -> HoneycombSession? {
        sessionManager?.session
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
        severity: Severity = .error,
        logger: OpenTelemetryApi.Logger = getDefaultErrorLogger()
    ) {
        let timestamp = Date()
        let type = String(describing: Mirror(reflecting: error).subjectType)
        let code = error.code
        let domain = error.domain
        let message = error.localizedDescription

        var errorAttributes = [
            "error.type": type.attributeValue(),
            "error.message": message.attributeValue(),
            "nserror.code": code.attributeValue(),
            "nserror.domain": domain.attributeValue(),
        ]
        .merging(attributes, uniquingKeysWith: { (_, last) in last })

        if let name = thread?.name {
            errorAttributes["thread.name"] = name.attributeValue()
        }

        logError(errorAttributes, severity, logger, timestamp)
    }

    /// Logs an `NSException`. This can be used for logging any caught exceptions in your own code that will not be logged by our crash instrumentation.
    /// - Parameters:
    ///   - exception: The `NSException` itself
    ///   - attributes: Additional attributes you would like to log along with the default ones provided.
    ///   - thread: Thread where the exception occurred. Add this to include additional attributes related to the thread
    ///   - severity: The severity of the exception. Typically .error or .fatal.
    ///   - logger: Defaults to the Honeycomb error `Logger`. Provide if you want to use a different OpenTelemetry `Logger`
    public static func log(
        exception: NSException,
        attributes: [String: AttributeValue] = [:],
        thread: Thread?,
        severity: Severity = .error,
        logger: OpenTelemetryApi.Logger = getDefaultErrorLogger()
    ) {
        let timestamp = Date()
        let type = exception.name.rawValue
        let message = exception.reason ?? exception.name.rawValue

        // TODO: Type and name seem wrong here. Which is right?
        var errorAttributes = [
            SemanticAttributes.exceptionType.rawValue: type.attributeValue(),
            SemanticAttributes.exceptionMessage.rawValue: message.attributeValue(),
            SemanticAttributes.exceptionStacktrace.rawValue: exception.callStackSymbols
                .joined(separator: "\n")
                .attributeValue(),
        ]
        .merging(attributes, uniquingKeysWith: { (_, last) in last })

        if let name = thread?.name {
            errorAttributes["thread.name"] = name.attributeValue()
        }

        logError(errorAttributes, .fatal, logger, timestamp)
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
        severity: Severity = .error,
        logger: OpenTelemetryApi.Logger = getDefaultErrorLogger()
    ) {
        let timestamp = Date()
        let type = String(describing: Mirror(reflecting: error).subjectType)
        let message = error.localizedDescription

        var errorAttributes = [
            "error.type": type.attributeValue(),
            "error.message": message.attributeValue(),
        ]
        .merging(attributes, uniquingKeysWith: { (_, last) in last })

        if let name = thread?.name {
            errorAttributes["thread.name"] = name.attributeValue()
        }

        logError(errorAttributes, severity, logger, timestamp)
    }

    private static func logError(
        _ attributes: [String: AttributeValue],
        _ severity: Severity,
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
            .setSeverity(severity)
            .emit()
    }

    @available(tvOS 16.0, iOS 16.0, macOS 13.0, watchOS 9, *)
    public static func setCurrentScreen(
        prefix: String? = nil,
        path: NavigationPath,
        reason: String? = nil
    ) {
        HoneycombNavigationProcessor.shared.reportNavigation(
            prefix: prefix,
            path: path,
            reason: reason
        )
    }
    public static func setCurrentScreen(prefix: String? = nil, path: String, reason: String? = nil)
    {
        HoneycombNavigationProcessor.shared.reportNavigation(
            prefix: prefix,
            path: path,
            reason: reason
        )
    }
    public static func setCurrentScreen(
        prefix: String? = nil,
        path: Encodable,
        reason: String? = nil
    ) {
        HoneycombNavigationProcessor.shared.reportNavigation(
            prefix: prefix,
            path: path,
            reason: reason
        )
    }
    public static func setCurrentScreen(
        prefix: String? = nil,
        path: [Encodable],
        reason: String? = nil
    ) {
        HoneycombNavigationProcessor.shared.reportNavigation(
            prefix: prefix,
            path: path,
            reason: reason
        )
    }
    public static func setCurrentScreen(prefix: String? = nil, path: Any, reason: String? = nil) {
        HoneycombNavigationProcessor.shared.reportNavigation(
            prefix: prefix,
            path: path,
            reason: reason
        )
    }
}
