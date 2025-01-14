import Foundation
import OpenTelemetrySdk

internal let runtimeVersion = ProcessInfo().operatingSystemVersionString
internal let otlpVersion = Resource.OTEL_SWIFT_SDK_VERSION

// Constants for keys and defaults in HoneycombOptions.

private let honeycombApiKeyKey = "HONEYCOMB_API_KEY"
private let honeycombTracesApiKeyKey = "HONEYCOMB_TRACES_APIKEY"
private let honeycombMetricsApiKeyKey = "HONEYCOMB_METRICS_APIKEY"
private let honeycombLogsApiKeyKey = "HONEYCOMB_LOGS_APIKEY"

private let honeycombDatasetKey = "HONEYCOMB_DATASET"
private let honeycombMetricsDatasetKey = "HONEYCOMB_METRICS_DATASET"

private let honeycombApiEndpointKey = "HONEYCOMB_API_ENDPOINT"
private let honeycombApiEndpointDefault = "https://api.honeycomb.io:443"
private let honeycombTracesEndpointKey = "HONEYCOMB_TRACES_ENDPOINT"
private let honeycombMetricsEndpointKey = "HONEYCOMB_METRICS_ENDPOINT"
private let honeycombLogsEndpointKey = "HONEYCOMB_LOGS_ENDPOINT"

private let sampleRateKey = "SAMPLE_RATE"
private let debugKey = "DEBUG"

private let otelServiceNameKey = "OTEL_SERVICE_NAME"
private let otelServiceNameDefault = "unknown_service"
private let otelResourceAttributesKey = "OTEL_RESOURCE_ATTRIBUTES"

private let otelTracesSamplerKey = "OTEL_TRACES_SAMPLER"
private let otelTracesSamplerDefault = "parentbased_always_on"
private let otelTracesSamplerArgKey = "OTEL_TRACES_SAMPLER_ARG"

private let otelPropagatorsKey = "OTEL_PROPAGATORS"
private let otelPropagatorsDefault = "tracecontext,baggage"

private let otelTracesExporterKey = "OTEL_TRACES_EXPORTER"
private let otelMetricsExporterKey = "OTEL_METRICS_EXPORTER"
private let otelLogsExporterKey = "OTEL_METRICS_EXPORTER"

private let otlpHeadersKey = "OTEL_EXPORTER_OTLP_HEADERS"
private let otlpTracesHeadersKey = "OTEL_EXPORTER_OTLP_TRACES_HEADERS"
private let otlpMetricsHeadersKey = "OTEL_EXPORTER_OTLP_METRICS_HEADERS"
private let otlpLogsHeadersKey = "OTEL_EXPORTER_OTLP_LOGS_HEADERS"

private let otlpTimeoutKey = "OTEL_EXPORTER_OTLP_TIMEOUT"
private let otlpTracesTimeoutKey = "OTEL_EXPORTER_OTLP_TRACES_TIMEOUT"
private let otlpMetricsTimeoutKey = "OTEL_EXPORTER_OTLP_METRICS_TIMEOUT"
private let otlpLogsTimeoutKey = "OTEL_EXPORTER_OTLP_LOGS_TIMEOUT"

private let otlpProtocolKey = "OTEL_EXPORTER_OTLP_PROTOCOL"
private let otlpTracesProtocolKey = "OTEL_EXPORTER_OTLP_TRACES_PROTOCOL"
private let otlpMetricsProtocolKey = "OTEL_EXPORTER_OTLP_METRICS_PROTOCOL"
private let otlpLogsProtocolKey = "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL"

/// The protocol for OTLP to use when talking to its backend.
public enum OTLPProtocol {
    case grpc
    case httpProtobuf
    case httpJSON
}

private let classicKeyRegex = #"^[a-f0-9]*$"#
private let ingestClassicKeyRegex = #"^hc[a-z]ic_[a-z0-9]*$"#

private func matchesRegex(pattern: String, string: String) -> Bool {
    return string.range(of: pattern, options: .regularExpression, range: nil, locale: nil) != nil
}

/// Returns whether the passed in API key is classic or not.
private func isClassic(key: String) -> Bool {
    return switch key.count {
    case 0: false
    case 32: matchesRegex(pattern: classicKeyRegex, string: key)
    case 64: matchesRegex(pattern: ingestClassicKeyRegex, string: key)
    default: false
    }
}

/// Gets the endpoint to use for a particular signal.
///
/// The logic is this:
/// 1. If HONEYCOMB_signal_ENDPOINT is set, return it.
/// 2. Determine the base url:
///    a. If HONEYCOMB_API_ENDPOINT is set, that's the base url.
///    b. Else, use the default as the base url.
/// 3. If the protocol is GRPC, return the base url.
/// 4. If the protocol is HTTP, return the base url with a suffix based on the signal.
///
/// Note that even though OpenTelemetry defines its own defaults for endpoints, they will never be
/// used, as the standard Honeycomb-specific logic falls back to its own default.
private func getHoneycombEndpoint(
    endpoint: String?,
    fallback: String,
    proto: OTLPProtocol,
    suffix: String
) -> String {
    if endpoint != nil {
        return endpoint!
    }
    if proto == .grpc {
        return fallback
    }
    return if fallback.hasSuffix("/") {
        "\(fallback)\(suffix)"
    } else {
        "\(fallback)/\(suffix)"
    }
}

// This is used with Dictionary.merge below.
private func takeSecond(_: String, second: String) -> String {
    return second
}

/// Gets the headers to use for a particular exporter.
private func getHeaders(
    apiKey: String,
    dataset: String?,
    generalHeaders: [String: String],
    signalHeaders: [String: String]
) -> [String: String] {
    var headers = ["x-otlp-version": otlpVersion]
    headers.merge(generalHeaders, uniquingKeysWith: takeSecond)

    headers.merge(["x-honeycomb-team": apiKey], uniquingKeysWith: takeSecond)
    if let dataset = dataset {
        headers.merge(["x-honeycomb-dataset": dataset], uniquingKeysWith: takeSecond)
    }

    headers.merge(signalHeaders, uniquingKeysWith: takeSecond)

    return headers
}

private func verifyExporter(source: HoneycombOptionsSource, key: String) throws {
    if let exporter = try source.getString(key)?.lowercased() {
        if exporter != "otlp" {
            throw HoneycombOptionsError.unsupportedExporter(
                "unsupported exporter \(exporter) for \(key)"
            )
        }
    }
}

extension Dictionary {
    mutating func putIfAbsent(_ key: Self.Key, _ value: Self.Value) {
        if self[key] != nil {
            return
        }
        self[key] = value
    }
}

/// The set of options for how to configure Honeycomb.
///
/// These keys and defaults are defined at:
/// https://github.com/honeycombio/specs/blob/main/specs/otel-sdk-distro.md
/// https://opentelemetry.io/docs/languages/sdk-configuration/general/
/// https://opentelemetry.io/docs/languages/sdk-configuration/otlp-exporter/
public struct HoneycombOptions {
    let tracesApiKey: String
    let metricsApiKey: String
    let logsApiKey: String
    let dataset: String?
    let metricsDataset: String?
    let tracesEndpoint: String
    let metricsEndpoint: String
    let logsEndpoint: String
    let sampleRate: Int
    let debug: Bool

    let serviceName: String
    let resourceAttributes: [String: String]
    let tracesSampler: String
    let tracesSamplerArg: String?
    let propagators: String

    let tracesHeaders: [String: String]
    let metricsHeaders: [String: String]
    let logsHeaders: [String: String]

    let tracesTimeout: TimeInterval
    let metricsTimeout: TimeInterval
    let logsTimeout: TimeInterval

    let tracesProtocol: OTLPProtocol
    let metricsProtocol: OTLPProtocol
    let logsProtocol: OTLPProtocol

    public class Builder {
        private var apiKey: String? = nil
        private var tracesApiKey: String? = nil
        private var metricsApiKey: String? = nil
        private var logsApiKey: String? = nil

        private var dataset: String? = nil
        private var metricsDataset: String? = nil

        private var apiEndpoint: String = honeycombApiEndpointDefault
        private var tracesEndpoint: String? = nil
        private var metricsEndpoint: String? = nil
        private var logsEndpoint: String? = nil

        private var sampleRate: Int = 1
        private var debug: Bool = false

        private var serviceName: String? = nil
        private var resourceAttributes: [String: String] = [:]
        private var tracesSampler: String = otelTracesSamplerDefault
        private var tracesSamplerArg: String? = nil
        private var propagators: String = otelPropagatorsDefault

        private var headers: [String: String] = [:]
        private var tracesHeaders: [String: String] = [:]
        private var metricsHeaders: [String: String] = [:]
        private var logsHeaders: [String: String] = [:]

        private var timeout: TimeInterval = 10.0
        private var tracesTimeout: TimeInterval? = nil
        private var metricsTimeout: TimeInterval? = nil
        private var logsTimeout: TimeInterval? = nil

        private var `protocol`: OTLPProtocol = .httpProtobuf
        private var tracesProtocol: OTLPProtocol? = nil
        private var metricsProtocol: OTLPProtocol? = nil
        private var logsProtocol: OTLPProtocol? = nil

        /// Creates a builder with default options.
        public init() {}

        internal convenience init(source: HoneycombOptionsSource) throws {
            self.init()
            try configureFromSource(source: source)
        }

        /// Creates a build with options pre-propulated from a plist file.
        public convenience init(contentsOfFile path: URL) throws {
            let data = try Data(contentsOf: path)
            let info =
                try PropertyListSerialization.propertyList(
                    from: data,
                    options: .mutableContainers,
                    format: nil
                ) as? [String: Any]
            try self.init(source: HoneycombOptionsSource(info: info))
        }

        private func configureFromSource(source: HoneycombOptionsSource) throws {
            // Make sure the exporters aren't set to anything other than OTLP.
            try verifyExporter(source: source, key: otelTracesExporterKey)
            try verifyExporter(source: source, key: otelMetricsExporterKey)
            try verifyExporter(source: source, key: otelLogsExporterKey)

            apiKey = try source.getString(honeycombApiKeyKey)
            tracesApiKey = try source.getString(honeycombTracesApiKeyKey)
            metricsApiKey = try source.getString(honeycombMetricsApiKeyKey)
            logsApiKey = try source.getString(honeycombLogsApiKeyKey)
            dataset = try source.getString(honeycombDatasetKey)
            metricsDataset = try source.getString(honeycombMetricsDatasetKey)
            apiEndpoint = try source.getString(honeycombApiEndpointKey) ?? apiEndpoint
            tracesEndpoint = try source.getString(honeycombTracesEndpointKey)
            metricsEndpoint = try source.getString(honeycombMetricsEndpointKey)
            logsEndpoint = try source.getString(honeycombLogsEndpointKey)
            sampleRate = try source.getInt(sampleRateKey) ?? sampleRate
            debug = try source.getBool(debugKey) ?? debug
            serviceName = try source.getString(otelServiceNameKey) ?? serviceName
            resourceAttributes = try source.getKeyValueList(otelResourceAttributesKey)
            tracesSampler = try source.getString(otelTracesSamplerKey) ?? tracesSampler
            tracesSamplerArg = try source.getString(otelTracesSamplerArgKey)
            propagators = try source.getString(otelPropagatorsKey) ?? propagators
            headers = try source.getKeyValueList(otlpHeadersKey)
            tracesHeaders = try source.getKeyValueList(otlpTracesHeadersKey)
            metricsHeaders = try source.getKeyValueList(otlpMetricsHeadersKey)
            logsHeaders = try source.getKeyValueList(otlpLogsHeadersKey)
            timeout = try source.getTimeInterval(otlpTimeoutKey) ?? timeout
            tracesTimeout = try source.getTimeInterval(otlpTracesTimeoutKey)
            metricsTimeout = try source.getTimeInterval(otlpMetricsTimeoutKey)
            logsTimeout = try source.getTimeInterval(otlpLogsTimeoutKey)
            `protocol` = try source.getOTLPProtocol(otlpProtocolKey) ?? `protocol`
            tracesProtocol = try source.getOTLPProtocol(otlpTracesProtocolKey)
            metricsProtocol = try source.getOTLPProtocol(otlpMetricsProtocolKey)
            logsProtocol = try source.getOTLPProtocol(otlpLogsProtocolKey)
        }

        public func setAPIKey(_ apiKey: String) -> Builder {
            self.apiKey = apiKey
            return self
        }

        public func setTracesAPIKey(_ apiKey: String) -> Builder {
            tracesApiKey = apiKey
            return self
        }

        public func setMetricsAPIKey(_ apiKey: String) -> Builder {
            metricsApiKey = apiKey
            return self
        }

        public func setLogsAPIKey(_ apiKey: String) -> Builder {
            logsApiKey = apiKey
            return self
        }

        public func setDataset(_ dataset: String) -> Builder {
            self.dataset = dataset
            return self
        }

        public func setMetricsDataset(_ dataset: String) -> Builder {
            metricsDataset = dataset
            return self
        }

        public func setAPIEndpoint(_ endpoint: String) -> Builder {
            apiEndpoint = endpoint
            return self
        }

        public func setTracesAPIEndpoint(_ endpoint: String) -> Builder {
            tracesEndpoint = endpoint
            return self
        }

        public func setMetricsAPIEndpoint(_ endpoint: String) -> Builder {
            metricsEndpoint = endpoint
            return self
        }

        public func setLogsAPIEndpoint(_ endpoint: String) -> Builder {
            logsEndpoint = endpoint
            return self
        }

        public func setSampleRate(_ sampleRate: Int) -> Builder {
            self.sampleRate = sampleRate
            return self
        }

        public func setDebug(_ debug: Bool) -> Builder {
            self.debug = debug
            return self
        }

        public func setServiceName(_ serviceName: String) -> Builder {
            self.serviceName = serviceName
            return self
        }

        public func setResourceAttributes(_ resources: [String: String]) -> Builder {
            resourceAttributes = resources
            return self
        }

        public func setTracesSampler(_ sampler: String) -> Builder {
            tracesSampler = sampler
            return self
        }

        public func setTracesSamplerArg(_ arg: String?) -> Builder {
            tracesSamplerArg = arg
            return self
        }

        public func setPropagators(_ propagators: String) -> Builder {
            self.propagators = propagators
            return self
        }

        public func setHeaders(_ headers: [String: String]) -> Builder {
            self.headers = headers
            return self
        }

        public func setTracesHeaders(_ headers: [String: String]) -> Builder {
            tracesHeaders = headers
            return self
        }

        public func setMetricsHeaders(_ headers: [String: String]) -> Builder {
            metricsHeaders = headers
            return self
        }

        public func setLogsHeaders(_ headers: [String: String]) -> Builder {
            logsHeaders = headers
            return self
        }

        public func setTimeout(_ timeout: TimeInterval) -> Builder {
            self.timeout = timeout
            return self
        }

        public func setTracesTimeout(_ timeout: TimeInterval) -> Builder {
            tracesTimeout = timeout
            return self
        }

        public func setMetricsTimeout(_ timeout: TimeInterval) -> Builder {
            metricsTimeout = timeout
            return self
        }

        public func setLogsTimeout(_ timeout: TimeInterval) -> Builder {
            logsTimeout = timeout
            return self
        }

        public func setProtocol(_ protocol: OTLPProtocol) -> Builder {
            self.`protocol` = `protocol`
            return self
        }

        public func setTracesProtocol(_ protocol: OTLPProtocol) -> Builder {
            tracesProtocol = `protocol`
            return self
        }

        public func setMetricsProtocol(_ protocol: OTLPProtocol) -> Builder {
            metricsProtocol = `protocol`
            return self
        }

        public func setLogsProtocol(_ protocol: OTLPProtocol) -> Builder {
            logsProtocol = `protocol`
            return self
        }

        public func build() throws -> HoneycombOptions {
            // If any API key isn't set, consider it a fatal error.
            let defaultApiKey: () throws -> String = {
                if self.apiKey == nil {
                    throw HoneycombOptionsError.missingAPIKey("missing API key: call setAPIKey()")
                }
                return self.apiKey!
            }

            // Collect the non-exporter-specific values.
            var resourceAttributes = self.resourceAttributes
            // Any explicit service name overrides the one in the resource attributes.
            let serviceName: String =
                self.serviceName
                ?? resourceAttributes["service.name"]
                ?? otelServiceNameDefault

            // Add automatic entries to resource attributes. According to the Honeycomb spec,
            // resource attributes should never be overwritten by automatic values. So, if there are
            // two different service names set, this will use the resource attributes version.

            // Make sure the service name is in the resource attributes.
            resourceAttributes.putIfAbsent("service.name", serviceName)
            // The SDK version is generated from build.gradle.kts.
            resourceAttributes.putIfAbsent(
                "honeycomb.distro.version",
                honeycombLibraryVersion
            )
            // Use the display version of Android. This is "unknown" when running tests in the JVM.
            resourceAttributes.putIfAbsent(
                "honeycomb.distro.runtime_version",
                runtimeVersion
            )

            let tracesApiKey: String = try self.tracesApiKey ?? defaultApiKey()
            let metricsApiKey: String = try self.metricsApiKey ?? defaultApiKey()
            let logsApiKey: String = try self.logsApiKey ?? defaultApiKey()

            let tracesHeaders =
                getHeaders(
                    apiKey: tracesApiKey,
                    dataset: isClassic(key: tracesApiKey) ? dataset : nil,
                    generalHeaders: headers,
                    signalHeaders: self.tracesHeaders
                )
            let metricsHeaders =
                getHeaders(
                    apiKey: metricsApiKey,
                    dataset: metricsDataset,
                    generalHeaders: headers,
                    signalHeaders: self.metricsHeaders
                )
            let logsHeaders =
                getHeaders(
                    apiKey: logsApiKey,
                    dataset: isClassic(key: tracesApiKey) ? dataset : nil,
                    generalHeaders: headers,
                    signalHeaders: self.logsHeaders
                )

            let tracesEndpoint = getHoneycombEndpoint(
                endpoint: self.tracesEndpoint,
                fallback: apiEndpoint,
                proto: tracesProtocol ?? `protocol`,
                suffix: "v1/traces"
            )
            let metricsEndpoint = getHoneycombEndpoint(
                endpoint: self.metricsEndpoint,
                fallback: apiEndpoint,
                proto: metricsProtocol ?? `protocol`,
                suffix: "v1/metrics"
            )
            let logsEndpoint = getHoneycombEndpoint(
                endpoint: self.logsEndpoint,
                fallback: apiEndpoint,
                proto: logsProtocol ?? `protocol`,
                suffix: "v1/logs"
            )

            return HoneycombOptions(
                tracesApiKey: tracesApiKey,
                metricsApiKey: metricsApiKey,
                logsApiKey: logsApiKey,
                dataset: dataset,
                metricsDataset: metricsDataset,
                tracesEndpoint: tracesEndpoint,
                metricsEndpoint: metricsEndpoint,
                logsEndpoint: logsEndpoint,
                sampleRate: sampleRate,
                debug: debug,
                serviceName: serviceName,
                resourceAttributes: resourceAttributes,
                tracesSampler: tracesSampler,
                tracesSamplerArg: tracesSamplerArg,
                propagators: propagators,
                tracesHeaders: tracesHeaders,
                metricsHeaders: metricsHeaders,
                logsHeaders: logsHeaders,
                tracesTimeout: tracesTimeout ?? timeout,
                metricsTimeout: metricsTimeout ?? timeout,
                logsTimeout: logsTimeout ?? timeout,
                tracesProtocol: tracesProtocol ?? `protocol`,
                metricsProtocol: metricsProtocol ?? `protocol`,
                logsProtocol: logsProtocol ?? `protocol`
            )
        }

    }
}
