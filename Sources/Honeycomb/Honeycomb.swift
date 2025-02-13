import Foundation
import MetricKit
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon
import OpenTelemetryProtocolExporterHttp
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

        // The default constructor includes a bunch of automatic values we want,
        // so it's important to create a default one and then merge our own.
        let resource = Resource()
            .merging(other: Resource(attributes: createAttributeDict(options.resourceAttributes)))

        // Traces

        var traceExporter: SpanExporter
        if options.tracesProtocol == .httpJSON {
            throw HoneycombOptionsError.unsupportedProtocol("http/json")
        } else {
            traceExporter = OtlpHttpTraceExporter(
                endpoint: tracesEndpoint,
                config: otlpTracesConfig
            )
        }

        let spanExporter =
            if options.debug {
                MultiSpanExporter(spanExporters: [traceExporter, StdoutSpanExporter()])
            } else {
                traceExporter
            }

        let spanProcessor = CompositeSpanProcessor()
        spanProcessor.addSpanProcessor(BatchSpanProcessor(spanExporter: spanExporter))
        if let clientSpanProcessor = options.spanProcessor {
            spanProcessor.addSpanProcessor(clientSpanProcessor)
        }

        let baggageSpanProcessor = HoneycombBaggageSpanProcessor(filter: { _ in true })

        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: spanProcessor)
            .add(spanProcessor: baggageSpanProcessor)
            .add(spanProcessor: HoneycombNavigationPathSpanProcessor())
            .add(
                spanProcessor: HoneycombSessionIdSpanProcessor(
                    debug: options.debug,
                    sessionLifetimeSeconds: options.sessionTimeout
                )
            )
            .with(resource: resource)
            .with(sampler: HoneycombDeterministicSampler(sampleRate: options.sampleRate))
            .build()

        // Metrics

        var metricExporter: MetricExporter
        if options.metricsProtocol == .httpJSON {
            throw HoneycombOptionsError.unsupportedProtocol("http/json")
        } else {
            metricExporter = OtlpHttpMetricExporter(
                endpoint: metricsEndpoint,
                config: otlpMetricsConfig
            )
        }

        let meterProvider = MeterProviderBuilder()
            .with(processor: MetricProcessorSdk())
            .with(exporter: metricExporter)
            .with(resource: Resource())
            .build()

        // Logs

        var logExporter: LogRecordExporter
        if options.logsProtocol == .httpJSON {
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

        installNetworkInstrumentation(options: options)
        installUINavigationInstrumentation()
        installWindowInstrumentation()

        if #available(iOS 13.0, macOS 12.0, *) {
            MXMetricManager.shared.add(self.metricKitSubscriber)
        }
    }

    @available(iOS 16.0, macOS 12.0, *)
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
