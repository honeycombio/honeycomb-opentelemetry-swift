import XCTest

@testable import Honeycomb

final class HoneycombOptionsTests: XCTestCase {
    func testOptionsFromPlist() throws {
        let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                    <key>HONEYCOMB_API_KEY</key>
                    <string>plist_key</string>
            </dict>
            </plist>
            """
        let plistBase64 = Data(plist.utf8).base64EncodedString()
        let dataString = "data:text/xml;base64,\(plistBase64)"
        let dataURL = URL(string: dataString)!

        let options = try HoneycombOptions.Builder(contentsOfFile: dataURL).build()

        XCTAssertEqual("plist_key", options.tracesApiKey)
    }

    func testOptionsDefaults() throws {
        let data: [String: String] = [
            "HONEYCOMB_API_KEY": "key"
        ]
        let source = HoneycombOptionsSource(info: data)
        let options = try HoneycombOptions.Builder(source: source).build()

        XCTAssertEqual("unknown_service", options.serviceName)
        let expectedResources = [
            "service.name": "unknown_service",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)

        XCTAssertEqual("https://api.honeycomb.io:443/v1/traces", options.tracesEndpoint)
        XCTAssertEqual("https://api.honeycomb.io:443/v1/metrics", options.metricsEndpoint)
        XCTAssertEqual("https://api.honeycomb.io:443/v1/logs", options.logsEndpoint)

        let expectedHeaders = [
            "x-honeycomb-team": "key",
            "x-otlp-version": otlpVersion,
        ]
        XCTAssertEqual(expectedHeaders, options.tracesHeaders)
        XCTAssertEqual(expectedHeaders, options.metricsHeaders)
        XCTAssertEqual(expectedHeaders, options.logsHeaders)

        XCTAssertEqual(10.0, options.tracesTimeout)
        XCTAssertEqual(10.0, options.metricsTimeout)
        XCTAssertEqual(10.0, options.logsTimeout)

        XCTAssertEqual(OTLPProtocol.httpProtobuf, options.tracesProtocol)
        XCTAssertEqual(OTLPProtocol.httpProtobuf, options.metricsProtocol)
        XCTAssertEqual(OTLPProtocol.httpProtobuf, options.logsProtocol)

        XCTAssertTrue(options.metricKitInstrumentationEnabled)
        XCTAssertTrue(options.urlSessionInstrumentationEnabled)
        XCTAssertTrue(options.uiKitInstrumentationEnabled)
        XCTAssertFalse(options.touchInstrumentationEnabled)
        XCTAssertTrue(options.unhandledExceptionInstrumentationEnabled)

        XCTAssertFalse(options.offlineCachingEnabled)
    }

    func testOptionsWithEmptyStrings() throws {
        let data: [String: String] = [
            "HONEYCOMB_API_KEY": "key",
            "OTEL_SERVICE_NAME": "",
            "OTEL_RESOURCE_ATTRIBUTES": "",
            "OTEL_TRACES_SAMPLER": "",
            "OTEL_TRACES_SAMPLER_ARG": "",
            "OTEL_PROPAGATORS": "",
            "OTEL_EXPORTER_OTLP_ENDPOINT": "",
            "OTEL_EXPORTER_OTLP_HEADERS": "",
            "OTEL_EXPORTER_OTLP_TIMEOUT": "",
            "OTEL_EXPORTER_OTLP_PROTOCOL": "",
        ]
        let source = HoneycombOptionsSource(info: data)
        let options = try HoneycombOptions.Builder(source: source).build()

        XCTAssertEqual("unknown_service", options.serviceName)
        XCTAssertNil(options.serviceVersion)
        let expectedResources = [
            "service.name": "unknown_service",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)

        XCTAssertEqual("https://api.honeycomb.io:443/v1/traces", options.tracesEndpoint)
        XCTAssertEqual("https://api.honeycomb.io:443/v1/metrics", options.metricsEndpoint)
        XCTAssertEqual("https://api.honeycomb.io:443/v1/logs", options.logsEndpoint)

        let expectedHeaders = [
            "x-honeycomb-team": "key",
            "x-otlp-version": otlpVersion,
        ]
        XCTAssertEqual(expectedHeaders, options.tracesHeaders)
        XCTAssertEqual(expectedHeaders, options.metricsHeaders)
        XCTAssertEqual(expectedHeaders, options.logsHeaders)

        XCTAssertEqual(10.0, options.tracesTimeout)
        XCTAssertEqual(10.0, options.metricsTimeout)
        XCTAssertEqual(10.0, options.logsTimeout)

        XCTAssertEqual(OTLPProtocol.httpProtobuf, options.tracesProtocol)
        XCTAssertEqual(OTLPProtocol.httpProtobuf, options.metricsProtocol)
        XCTAssertEqual(OTLPProtocol.httpProtobuf, options.logsProtocol)
    }

    func testOptionsWithFallbacks() throws {
        let data: [String: String] = [
            "HONEYCOMB_API_KEY": "key",
            "HONEYCOMB_API_ENDPOINT": "http://example.com:1234",
            "OTEL_SERVICE_NAME": "service",
            "OTEL_SERVICE_VERSION": "1",
            "OTEL_RESOURCE_ATTRIBUTES": "resource=aaa",
            "OTEL_TRACES_SAMPLER": "sampler",
            "OTEL_TRACES_SAMPLER_ARG": "arg",
            "OTEL_PROPAGATORS": "propagators",
            "OTEL_EXPORTER_OTLP_HEADERS": "header=bbb",
            "OTEL_EXPORTER_OTLP_TIMEOUT": "30000",
            "OTEL_EXPORTER_OTLP_PROTOCOL": "http/json",
        ]
        let source = HoneycombOptionsSource(info: data)
        let options = try HoneycombOptions.Builder(source: source).build()

        XCTAssertEqual("service", options.serviceName)
        XCTAssertEqual("1", options.serviceVersion)
        let expectedResources = [
            "resource": "aaa",
            "service.name": "service",
            "service.version": "1",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)

        XCTAssertEqual("http://example.com:1234/v1/traces", options.tracesEndpoint)
        XCTAssertEqual("http://example.com:1234/v1/metrics", options.metricsEndpoint)
        XCTAssertEqual("http://example.com:1234/v1/logs", options.logsEndpoint)

        let expectedHeaders = [
            "header": "bbb",
            "x-honeycomb-team": "key",
            "x-otlp-version": otlpVersion,
        ]
        XCTAssertEqual(expectedHeaders, options.tracesHeaders)
        XCTAssertEqual(expectedHeaders, options.metricsHeaders)
        XCTAssertEqual(expectedHeaders, options.logsHeaders)

        XCTAssertEqual(30.0, options.tracesTimeout)
        XCTAssertEqual(30.0, options.metricsTimeout)
        XCTAssertEqual(30.0, options.logsTimeout)

        XCTAssertEqual(OTLPProtocol.httpJSON, options.tracesProtocol)
        XCTAssertEqual(OTLPProtocol.httpJSON, options.metricsProtocol)
        XCTAssertEqual(OTLPProtocol.httpJSON, options.logsProtocol)
    }

    func testOptionsSetWithFallbacks() throws {
        let options = try HoneycombOptions.Builder()
            .setAPIKey("key")
            .setAPIEndpoint("http://api.example.com:1234")
            .setSampleRate(42)
            .setDebug(true)
            .setServiceName("service")
            .setServiceVersion("1")
            .setResourceAttributes(["resource": "aaa"])
            .setTimeout(30)
            .setHeaders(["header": "hhh"])
            .setProtocol(OTLPProtocol.httpJSON)
            .build()

        XCTAssertEqual("service", options.serviceName)
        XCTAssertEqual("1", options.serviceVersion)
        let expectedResources = [
            "resource": "aaa",
            "service.name": "service",
            "service.version": "1",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)

        XCTAssertEqual("http://api.example.com:1234/v1/traces", options.tracesEndpoint)
        XCTAssertEqual("http://api.example.com:1234/v1/metrics", options.metricsEndpoint)
        XCTAssertEqual("http://api.example.com:1234/v1/logs", options.logsEndpoint)

        let expectedHeaders = [
            "header": "hhh",
            "x-honeycomb-team": "key",
            "x-otlp-version": otlpVersion,
        ]
        XCTAssertEqual(expectedHeaders, options.tracesHeaders)
        XCTAssertEqual(expectedHeaders, options.metricsHeaders)
        XCTAssertEqual(expectedHeaders, options.logsHeaders)

        XCTAssertEqual(30.0, options.tracesTimeout)
        XCTAssertEqual(30.0, options.metricsTimeout)
        XCTAssertEqual(30.0, options.logsTimeout)

        XCTAssertEqual(OTLPProtocol.httpJSON, options.tracesProtocol)
        XCTAssertEqual(OTLPProtocol.httpJSON, options.metricsProtocol)
        XCTAssertEqual(OTLPProtocol.httpJSON, options.logsProtocol)
    }

    func testOptionsFullySpecified() throws {
        let data: [String: String] = [
            "DEBUG": "true",
            "HONEYCOMB_API_KEY": "key",
            "HONEYCOMB_DATASET": "dataset",
            "HONEYCOMB_METRICS_DATASET": "metrics",
            "HONEYCOMB_TRACES_APIKEY": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "HONEYCOMB_METRICS_APIKEY": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            "HONEYCOMB_LOGS_APIKEY": "cccccccccccccccccccccccccccccccc",
            "HONEYCOMB_TRACES_ENDPOINT": "http://traces.example.com:1234",
            "HONEYCOMB_METRICS_ENDPOINT": "http://metrics.example.com:1234",
            "HONEYCOMB_LOGS_ENDPOINT": "http://logs.example.com:1234",
            "OTEL_SERVICE_NAME": "service",
            "OTEL_SERVICE_VERSION": "1",
            "OTEL_RESOURCE_ATTRIBUTES": "resource=aaa",
            "OTEL_TRACES_SAMPLER": "sampler",
            "OTEL_TRACES_SAMPLER_ARG": "arg",
            "OTEL_PROPAGATORS": "propagators",
            "OTEL_EXPORTER_OTLP_ENDPOINT": "http://example.com:1234",
            "OTEL_EXPORTER_OTLP_TIMEOUT": "30000",
            "OTEL_EXPORTER_OTLP_PROTOCOL": "http/json",
            "OTEL_EXPORTER_OTLP_TRACES_HEADERS": "header=ttt",
            "OTEL_EXPORTER_OTLP_TRACES_TIMEOUT": "40000",
            "OTEL_EXPORTER_OTLP_TRACES_PROTOCOL": "grpc",
            "OTEL_EXPORTER_OTLP_METRICS_HEADERS": "header=mmm",
            "OTEL_EXPORTER_OTLP_METRICS_TIMEOUT": "50000",
            "OTEL_EXPORTER_OTLP_METRICS_PROTOCOL": "grpc",
            "OTEL_EXPORTER_OTLP_LOGS_HEADERS": "header=lll",
            "OTEL_EXPORTER_OTLP_LOGS_TIMEOUT": "60000",
            "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL": "grpc",
            "SAMPLE_RATE": "42",
        ]
        let source = HoneycombOptionsSource(info: data)
        let options = try HoneycombOptions.Builder(source: source).build()

        XCTAssertEqual("service", options.serviceName)
        XCTAssertEqual("1", options.serviceVersion)
        let expectedResources = [
            "resource": "aaa",
            "service.name": "service",
            "service.version": "1",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)

        XCTAssertEqual("http://traces.example.com:1234", options.tracesEndpoint)
        XCTAssertEqual("http://metrics.example.com:1234", options.metricsEndpoint)
        XCTAssertEqual("http://logs.example.com:1234", options.logsEndpoint)

        XCTAssertEqual(
            [
                "header": "ttt",
                "x-honeycomb-dataset": "dataset",
                "x-honeycomb-team": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                "x-otlp-version": otlpVersion,
            ],
            options.tracesHeaders
        )
        XCTAssertEqual(
            [
                "header": "mmm",
                "x-honeycomb-dataset": "metrics",
                "x-honeycomb-team": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                "x-otlp-version": otlpVersion,
            ],
            options.metricsHeaders
        )
        XCTAssertEqual(
            [
                "header": "lll",
                "x-honeycomb-dataset": "dataset",
                "x-honeycomb-team": "cccccccccccccccccccccccccccccccc",
                "x-otlp-version": otlpVersion,
            ],
            options.logsHeaders
        )

        XCTAssertEqual(40.0, options.tracesTimeout)
        XCTAssertEqual(50.0, options.metricsTimeout)
        XCTAssertEqual(60.0, options.logsTimeout)

        XCTAssertEqual(OTLPProtocol.grpc, options.tracesProtocol)
        XCTAssertEqual(OTLPProtocol.grpc, options.metricsProtocol)
        XCTAssertEqual(OTLPProtocol.grpc, options.logsProtocol)

        XCTAssertTrue(options.debug)
        XCTAssertEqual(42, options.sampleRate)
    }

    func testOptionsSetValues() throws {
        let options = try HoneycombOptions.Builder()
            .setDataset("dataset")
            .setMetricsDataset("metrics")
            .setTracesAPIKey("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
            .setMetricsAPIKey("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
            .setLogsAPIKey("cccccccccccccccccccccccccccccccc")
            .setTracesAPIEndpoint("http://traces.example.com:1234")
            .setMetricsAPIEndpoint("http://metrics.example.com:1234")
            .setLogsAPIEndpoint("http://logs.example.com:1234")
            .setSampleRate(42)
            .setDebug(true)
            .setServiceName("service")
            .setServiceVersion("1")
            .setResourceAttributes(["resource": "aaa"])
            .setTracesTimeout(40)
            .setMetricsTimeout(50)
            .setLogsTimeout(60)
            .setTracesHeaders(["header": "ttt"])
            .setMetricsHeaders(["header": "mmm"])
            .setLogsHeaders(["header": "lll"])
            .setTracesProtocol(OTLPProtocol.grpc)
            .setMetricsProtocol(OTLPProtocol.grpc)
            .setLogsProtocol(OTLPProtocol.grpc)
            .setMetricKitInstrumentationEnabled(false)
            .setURLSessionInstrumentationEnabled(false)
            .setUIKitInstrumentationEnabled(false)
            .setTouchInstrumentationEnabled(true)
            .setUnhandledExceptionInstrumentationEnabled(false)
            .setOfflineCachingEnabled(true)
            .build()

        XCTAssertEqual("service", options.serviceName)
        XCTAssertEqual("1", options.serviceVersion)
        let expectedResources = [
            "resource": "aaa",
            "service.name": "service",
            "service.version": "1",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)

        XCTAssertEqual("http://traces.example.com:1234", options.tracesEndpoint)
        XCTAssertEqual("http://metrics.example.com:1234", options.metricsEndpoint)
        XCTAssertEqual("http://logs.example.com:1234", options.logsEndpoint)

        XCTAssertEqual(
            [
                "header": "ttt",
                "x-honeycomb-dataset": "dataset",
                "x-honeycomb-team": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                "x-otlp-version": otlpVersion,
            ],
            options.tracesHeaders
        )
        XCTAssertEqual(
            [
                "header": "mmm",
                "x-honeycomb-dataset": "metrics",
                "x-honeycomb-team": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                "x-otlp-version": otlpVersion,
            ],
            options.metricsHeaders
        )
        XCTAssertEqual(
            [
                "header": "lll",
                "x-honeycomb-dataset": "dataset",
                "x-honeycomb-team": "cccccccccccccccccccccccccccccccc",
                "x-otlp-version": otlpVersion,
            ],
            options.logsHeaders
        )

        XCTAssertEqual(40.0, options.tracesTimeout)
        XCTAssertEqual(50.0, options.metricsTimeout)
        XCTAssertEqual(60.0, options.logsTimeout)

        XCTAssertEqual(OTLPProtocol.grpc, options.tracesProtocol)
        XCTAssertEqual(OTLPProtocol.grpc, options.metricsProtocol)
        XCTAssertEqual(OTLPProtocol.grpc, options.logsProtocol)

        XCTAssertTrue(options.debug)
        XCTAssertEqual(42, options.sampleRate)

        XCTAssertFalse(options.metricKitInstrumentationEnabled)
        XCTAssertFalse(options.urlSessionInstrumentationEnabled)
        XCTAssertFalse(options.uiKitInstrumentationEnabled)
        XCTAssertTrue(options.touchInstrumentationEnabled)
        XCTAssertFalse(options.unhandledExceptionInstrumentationEnabled)
        XCTAssertTrue(options.offlineCachingEnabled)
    }

    func testDatasetSetWithClassicKey() throws {
        let key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

        let options = try HoneycombOptions.Builder()
            .setDataset("dataset")
            .setMetricsDataset("metrics")
            .setAPIKey(key)
            .build()

        XCTAssertEqual(
            [
                "x-honeycomb-dataset": "dataset",
                "x-honeycomb-team": key,
                "x-otlp-version": otlpVersion,
            ],
            options.tracesHeaders
        )
        XCTAssertEqual(
            [
                "x-honeycomb-dataset": "metrics",
                "x-honeycomb-team": key,
                "x-otlp-version": otlpVersion,
            ],
            options.metricsHeaders
        )
        XCTAssertEqual(
            [
                "x-honeycomb-dataset": "dataset",
                "x-honeycomb-team": key,
                "x-otlp-version": otlpVersion,
            ],
            options.logsHeaders
        )
    }

    func testDatasetSetWithIngestClassicKey() throws {
        let key = "hcaic_7890123456789012345678901234567890123456789012345678901234"

        let options = try HoneycombOptions.Builder()
            .setDataset("dataset")
            .setMetricsDataset("metrics")
            .setAPIKey(key)
            .build()

        XCTAssertEqual(
            [
                "x-honeycomb-dataset": "dataset",
                "x-honeycomb-team": key,
                "x-otlp-version": otlpVersion,
            ],
            options.tracesHeaders
        )
        XCTAssertEqual(
            [
                "x-honeycomb-dataset": "metrics",
                "x-honeycomb-team": key,
                "x-otlp-version": otlpVersion,
            ],
            options.metricsHeaders
        )
        XCTAssertEqual(
            [
                "x-honeycomb-dataset": "dataset",
                "x-honeycomb-team": key,
                "x-otlp-version": otlpVersion,
            ],
            options.logsHeaders
        )
    }

    func testDatasetNotSetWithNewKey() throws {
        let key = "not_classic"

        let options = try HoneycombOptions.Builder()
            .setDataset("dataset")
            .setMetricsDataset("metrics")
            .setAPIKey(key)
            .build()

        XCTAssertEqual(
            [
                "x-honeycomb-team": key,
                "x-otlp-version": otlpVersion,
            ],
            options.tracesHeaders
        )
        XCTAssertEqual(
            [
                "x-honeycomb-dataset": "metrics",
                "x-honeycomb-team": key,
                "x-otlp-version": otlpVersion,
            ],
            options.metricsHeaders
        )
        XCTAssertEqual(
            [
                "x-honeycomb-team": key,
                "x-otlp-version": otlpVersion,
            ],
            options.logsHeaders
        )
    }

    func testHeaderParsing() throws {
        let dict = try parseKeyValueList("foo=bar,baz=123%20456")
        XCTAssertEqual(2, dict.count)
        XCTAssertEqual("bar", dict["foo"])
        XCTAssertEqual("123 456", dict["baz"])
    }

    func testHeaderMerging() throws {
        let data = [
            "HONEYCOMB_API_KEY": "key",
            "OTEL_EXPORTER_OTLP_HEADERS": "foo=bar,baz=qux",
            "OTEL_EXPORTER_OTLP_TRACES_HEADERS": "foo=bar2,merged=yes",
        ]
        let source = HoneycombOptionsSource(info: data)
        let options = try HoneycombOptions.Builder(source: source).build()

        let expected = [
            "baz": "qux",
            "foo": "bar2",
            "merged": "yes",
            "x-honeycomb-team": "key",
            "x-otlp-version": otlpVersion,
        ]
        XCTAssertEqual(expected, options.tracesHeaders)
    }

    func testServiceNameDefault() throws {
        let data: [String: String] = [
            "HONEYCOMB_API_KEY": "key"
        ]
        let source = HoneycombOptionsSource(info: data)
        let options = try HoneycombOptions.Builder(source: source).build()

        XCTAssertEqual("unknown_service", options.serviceName)
        XCTAssertNil(options.serviceVersion)
        let expectedResources = [
            "service.name": "unknown_service",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)
    }

    func testServiceNameFromResourceAttributes() throws {
        let data = [
            "HONEYCOMB_API_KEY": "key",
            "OTEL_RESOURCE_ATTRIBUTES": "service.name=resource_name,service.version=1",
        ]
        let source = HoneycombOptionsSource(info: data)
        let options = try HoneycombOptions.Builder(source: source).build()

        XCTAssertEqual("resource_name", options.serviceName)
        XCTAssertEqual("1", options.serviceVersion)
        let expectedResources = [
            "service.name": "resource_name",
            "service.version": "1",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)
    }

    func testIndividualSourceVariablesTakePrecedence() throws {
        let data = [
            "HONEYCOMB_API_KEY": "key",
            "OTEL_SERVICE_NAME": "service_name",
            "OTEL_SERVICE_VERSION": "2",
            "OTEL_RESOURCE_ATTRIBUTES": "service.name=resource_name,service.version=1",
        ]
        let source = HoneycombOptionsSource(info: data)
        let options = try HoneycombOptions.Builder(source: source)
            .build()

        XCTAssertEqual("service_name", options.serviceName)
        XCTAssertEqual("2", options.serviceVersion)
        let expectedResources = [
            "service.name": "service_name",
            "service.version": "2",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)
    }

    func testResourceAttributeSetterTakesPrecedenceOverResourceSource() throws {
        let data = [
            "HONEYCOMB_API_KEY": "key",
            "OTEL_RESOURCE_ATTRIBUTES": "service.name=resource_name,service.version=1,other.attr=1",
        ]
        let source = HoneycombOptionsSource(info: data)
        let resourceAttributes = [
            "service.name": "service_name",
            "service.version": "2",
        ]
        let options = try HoneycombOptions.Builder(source: source)
            .setResourceAttributes(resourceAttributes)
            .build()

        XCTAssertEqual("service_name", options.serviceName)
        XCTAssertEqual("2", options.serviceVersion)
        let expectedResources = [
            "service.name": "service_name",
            "service.version": "2",
            "other.attr": "1",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)
    }

    func testResourceAttributeSetterTakesPrecedenceOverSource() throws {
        let data = [
            "HONEYCOMB_API_KEY": "key",
            "OTEL_SERVICE_NAME": "resource_name",
            "OTEL_SERVICE_VERSION": "1",
        ]
        let source = HoneycombOptionsSource(info: data)
        let resourceAttributes = [
            "service.name": "service_name",
            "service.version": "2",
        ]
        let options = try HoneycombOptions.Builder(source: source)
            .setResourceAttributes(resourceAttributes)
            .build()

        XCTAssertEqual("service_name", options.serviceName)
        XCTAssertEqual("2", options.serviceVersion)
        let expectedResources = [
            "service.name": "service_name",
            "service.version": "2",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)
    }

    func testIndividualSettersTakePrecedenceOverSource() throws {
        let data = [
            "HONEYCOMB_API_KEY": "key",
            "OTEL_SERVICE_NAME": "resource_name",
            "OTEL_SERVICE_VERSION": "1",
        ]
        let source = HoneycombOptionsSource(info: data)
        let options = try HoneycombOptions.Builder(source: source)
            .setServiceName("service_name")
            .setServiceVersion("2")
            .build()

        XCTAssertEqual("service_name", options.serviceName)
        XCTAssertEqual("2", options.serviceVersion)
        let expectedResources = [
            "service.name": "service_name",
            "service.version": "2",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)
    }

    func testIndividualSettersTakePrecedenceOverSources() throws {
        let data = [
            "HONEYCOMB_API_KEY": "key",
            "OTEL_RESOURCE_ATTRIBUTES": "service.name=resource_name,service.version=1",
            "OTEL_SERVICE_NAME": "service_name",
            "OTEL_SERVICE_VERSION": "2",
        ]
        let source = HoneycombOptionsSource(info: data)
        let options = try HoneycombOptions.Builder(source: source)
            .setServiceName("override_name")
            .setServiceVersion("3")
            .build()

        XCTAssertEqual("override_name", options.serviceName)
        XCTAssertEqual("3", options.serviceVersion)
        let expectedResources = [
            "service.name": "override_name",
            "service.version": "3",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)
    }

    func testIndividualSettersTakePrecedenceOverResourceAttributeSetter() throws {
        let data = [
            "HONEYCOMB_API_KEY": "key"
        ]
        let source = HoneycombOptionsSource(info: data)
        let resourceAttributes = [
            "service.name": "resource_name",
            "service.version": "1",
        ]
        let options = try HoneycombOptions.Builder(source: source)
            .setResourceAttributes(resourceAttributes)
            .setServiceName("service_name")
            .setServiceVersion("2")
            .build()

        XCTAssertEqual("service_name", options.serviceName)
        XCTAssertEqual("2", options.serviceVersion)
        let expectedResources = [
            "service.name": "service_name",
            "service.version": "2",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)
    }

    // very similar to the test above, but note the ordering of the setResourceAttributes() call vs. the setServiceName() call
    func testResourceAttributeSetterTakesPrecedenceOverIndividualSetters() throws {
        let data = [
            "HONEYCOMB_API_KEY": "key"
        ]
        let source = HoneycombOptionsSource(info: data)
        let resourceAttributes = [
            "service.name": "resource_name",
            "service.version": "1",
        ]
        let options = try HoneycombOptions.Builder(source: source)
            .setServiceName("service_name")
            .setServiceVersion("2")
            .setResourceAttributes(resourceAttributes)
            .build()

        XCTAssertEqual("resource_name", options.serviceName)
        XCTAssertEqual("1", options.serviceVersion)
        let expectedResources = [
            "service.name": "resource_name",
            "service.version": "1",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion,
            "telemetry.distro.version": honeycombLibraryVersion,
            "telemetry.distro.name": "honeycomb-opentelemetry-swift",
        ]
        XCTAssertEqual(expectedResources, options.resourceAttributes)
    }

    func testMalformedKeyValueString() throws {
        XCTAssertThrowsError(try parseKeyValueList("foo=bar,baz")) { e in
            XCTAssert(e is HoneycombOptionsError)
            XCTAssertEqual(e as? HoneycombOptionsError, .malformedKeyValueString("baz"))
        }
    }

    func testMissingAPIKey() throws {
        var data: [String: String] = [:]
        var source = HoneycombOptionsSource(info: data)

        XCTAssertThrowsError(try HoneycombOptions.Builder(source: source).build()) { e in
            XCTAssert(e is HoneycombOptionsError)
            XCTAssertEqual(
                e as? HoneycombOptionsError,
                .missingAPIKey("missing API key: call setAPIKey() or setTracesAPIKey()")
            )
        }

        data = [
            "HONEYCOMB_API_ENDPOINT": "https://custom.collector:443"
        ]
        source = HoneycombOptionsSource(info: data)

        XCTAssertNoThrow(try HoneycombOptions.Builder(source: source).build())
    }

    func testIncorrectType() throws {
        let data = [
            "OTEL_EXPORTER_OTLP_TIMEOUT": "not a number"
        ]
        let source = HoneycombOptionsSource(info: data)

        XCTAssertThrowsError(try HoneycombOptions.Builder(source: source).build()) { e in
            XCTAssert(e is HoneycombOptionsError)
            XCTAssertEqual(
                e as? HoneycombOptionsError,
                .incorrectType("OTEL_EXPORTER_OTLP_TIMEOUT")
            )
        }
    }

    func testUnsupportedExporter() throws {
        let data = [
            "OTEL_TRACES_EXPORTER": "invalid-exporter"
        ]
        let source = HoneycombOptionsSource(info: data)

        XCTAssertThrowsError(try HoneycombOptions.Builder(source: source).build()) { e in
            XCTAssert(e is HoneycombOptionsError)
            XCTAssertEqual(
                e as? HoneycombOptionsError,
                .unsupportedExporter(
                    "unsupported exporter invalid-exporter for OTEL_TRACES_EXPORTER"
                )
            )
        }
    }

    func testUnsupportedProtocol() throws {
        let data = [
            "OTEL_EXPORTER_OTLP_PROTOCOL": "invalid-protocol"
        ]
        let source = HoneycombOptionsSource(info: data)

        XCTAssertThrowsError(try HoneycombOptions.Builder(source: source).build()) { e in
            XCTAssert(e is HoneycombOptionsError)
            XCTAssertEqual(
                e as? HoneycombOptionsError,
                .unsupportedProtocol("invalid protocol invalid-protocol")
            )
        }
    }
}
