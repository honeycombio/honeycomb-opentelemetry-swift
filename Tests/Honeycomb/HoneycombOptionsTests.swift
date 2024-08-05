import XCTest
@testable import honeycomb_opentelemetry_swift

final class HoneycombOptionsTests: XCTestCase {
    func testConfigDefaults() throws {
        let data: [String:String] = [
            "HONEYCOMB_API_KEY": "key",
        ]
        let source = HoneycombOptionsSource(info: data)
        let config = try HoneycombOptions.Builder(source: source).build()

        XCTAssertEqual("unknown_service", config.serviceName)
        let expectedResources = [
            "service.name": "unknown_service",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion
        ]
        XCTAssertEqual(expectedResources, config.resourceAttributes)

        XCTAssertEqual("parentbased_always_on", config.tracesSampler)
        XCTAssertNil(config.tracesSamplerArg)
        XCTAssertEqual("tracecontext,baggage", config.propagators)

        XCTAssertEqual("https://api.honeycomb.io:443/v1/traces", config.tracesEndpoint)
        XCTAssertEqual("https://api.honeycomb.io:443/v1/metrics", config.metricsEndpoint)
        XCTAssertEqual("https://api.honeycomb.io:443/v1/logs", config.logsEndpoint)

        let expectedHeaders = [
            "x-honeycomb-team": "key",
            "x-otlp-version": honeycombLibraryVersion
        ]
        XCTAssertEqual(expectedHeaders, config.tracesHeaders)
        XCTAssertEqual(expectedHeaders, config.metricsHeaders)
        XCTAssertEqual(expectedHeaders, config.logsHeaders)

        XCTAssertEqual(10.0, config.tracesTimeout)
        XCTAssertEqual(10.0, config.metricsTimeout)
        XCTAssertEqual(10.0, config.logsTimeout)

        XCTAssertEqual(OTLPProtocol.httpProtobuf, config.tracesProtocol)
        XCTAssertEqual(OTLPProtocol.httpProtobuf, config.metricsProtocol)
        XCTAssertEqual(OTLPProtocol.httpProtobuf, config.logsProtocol)
    }

    func testConfigWithEmptyStrings() throws {
        let data: [String:String] = [
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
        let config = try HoneycombOptions.Builder(source: source).build()

        XCTAssertEqual("unknown_service", config.serviceName)
        let expectedResources = [
            "service.name": "unknown_service",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion
        ]
        XCTAssertEqual(expectedResources, config.resourceAttributes)

        XCTAssertEqual("parentbased_always_on", config.tracesSampler)
        XCTAssertNil(config.tracesSamplerArg)
        XCTAssertEqual("tracecontext,baggage", config.propagators)

        XCTAssertEqual("https://api.honeycomb.io:443/v1/traces", config.tracesEndpoint)
        XCTAssertEqual("https://api.honeycomb.io:443/v1/metrics", config.metricsEndpoint)
        XCTAssertEqual("https://api.honeycomb.io:443/v1/logs", config.logsEndpoint)

        let expectedHeaders = [
            "x-honeycomb-team": "key",
            "x-otlp-version": honeycombLibraryVersion
        ]
        XCTAssertEqual(expectedHeaders, config.tracesHeaders)
        XCTAssertEqual(expectedHeaders, config.metricsHeaders)
        XCTAssertEqual(expectedHeaders, config.logsHeaders)

        XCTAssertEqual(10.0, config.tracesTimeout)
        XCTAssertEqual(10.0, config.metricsTimeout)
        XCTAssertEqual(10.0, config.logsTimeout)

        XCTAssertEqual(OTLPProtocol.httpProtobuf, config.tracesProtocol)
        XCTAssertEqual(OTLPProtocol.httpProtobuf, config.metricsProtocol)
        XCTAssertEqual(OTLPProtocol.httpProtobuf, config.logsProtocol)
    }

    func testConfigWithFallbacks() throws {
        let data: [String:String] = [
            "HONEYCOMB_API_KEY": "key",
            "HONEYCOMB_API_ENDPOINT": "http://example.com:1234",
            "OTEL_SERVICE_NAME": "service",
            "OTEL_RESOURCE_ATTRIBUTES": "resource=aaa",
            "OTEL_TRACES_SAMPLER": "sampler",
            "OTEL_TRACES_SAMPLER_ARG": "arg",
            "OTEL_PROPAGATORS": "propagators",
            "OTEL_EXPORTER_OTLP_HEADERS": "header=bbb",
            "OTEL_EXPORTER_OTLP_TIMEOUT": "30000",
            "OTEL_EXPORTER_OTLP_PROTOCOL": "http/json",
        ]
        let source = HoneycombOptionsSource(info: data)
        let config = try HoneycombOptions.Builder(source: source).build()

        XCTAssertEqual("service", config.serviceName)
        let expectedResources = [
            "resource": "aaa",
            "service.name": "service",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion
        ]
        XCTAssertEqual(expectedResources, config.resourceAttributes)

        XCTAssertEqual("sampler", config.tracesSampler)
        XCTAssertEqual("arg", config.tracesSamplerArg)
        XCTAssertEqual("propagators", config.propagators)

        XCTAssertEqual("http://example.com:1234/v1/traces", config.tracesEndpoint)
        XCTAssertEqual("http://example.com:1234/v1/metrics", config.metricsEndpoint)
        XCTAssertEqual("http://example.com:1234/v1/logs", config.logsEndpoint)

        let expectedHeaders = [
            "header": "bbb",
            "x-honeycomb-team": "key",
            "x-otlp-version": honeycombLibraryVersion
        ]
        XCTAssertEqual(expectedHeaders, config.tracesHeaders)
        XCTAssertEqual(expectedHeaders, config.metricsHeaders)
        XCTAssertEqual(expectedHeaders, config.logsHeaders)

        XCTAssertEqual(30.0, config.tracesTimeout)
        XCTAssertEqual(30.0, config.metricsTimeout)
        XCTAssertEqual(30.0, config.logsTimeout)

        XCTAssertEqual(OTLPProtocol.httpJSON, config.tracesProtocol)
        XCTAssertEqual(OTLPProtocol.httpJSON, config.metricsProtocol)
        XCTAssertEqual(OTLPProtocol.httpJSON, config.logsProtocol)
    }

    func testConfigFullySpecified() throws {
        let data: [String:String] = [
            "DEBUG": "true",
            "HONEYCOMB_API_KEY": "key",
            "HONEYCOMB_TRACES_APIKEY": "traces_key",
            "HONEYCOMB_METRICS_APIKEY": "metrics_key",
            "HONEYCOMB_LOGS_APIKEY": "logs_key",
            "HONEYCOMB_TRACES_ENDPOINT": "http://traces.example.com:1234",
            "HONEYCOMB_METRICS_ENDPOINT": "http://metrics.example.com:1234",
            "HONEYCOMB_LOGS_ENDPOINT": "http://logs.example.com:1234",
            "OTEL_SERVICE_NAME": "service",
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
            "SAMPLE_RATE": "42"
        ]
        let source = HoneycombOptionsSource(info: data)
        let config = try HoneycombOptions.Builder(source: source).build()

        XCTAssertEqual("service", config.serviceName)
        let expectedResources = [
            "resource": "aaa",
            "service.name": "service",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion
        ]
        XCTAssertEqual(expectedResources, config.resourceAttributes)

        XCTAssertEqual("sampler", config.tracesSampler)
        XCTAssertEqual("arg", config.tracesSamplerArg)
        XCTAssertEqual("propagators", config.propagators)

        XCTAssertEqual("http://traces.example.com:1234", config.tracesEndpoint)
        XCTAssertEqual("http://metrics.example.com:1234", config.metricsEndpoint)
        XCTAssertEqual("http://logs.example.com:1234", config.logsEndpoint)

        XCTAssertEqual([
            "header": "ttt",
            "x-honeycomb-team": "traces_key",
            "x-otlp-version": honeycombLibraryVersion
        ], config.tracesHeaders)
        XCTAssertEqual([
            "header": "mmm",
            "x-honeycomb-team": "metrics_key",
            "x-otlp-version": honeycombLibraryVersion
        ], config.metricsHeaders)
        XCTAssertEqual([
            "header": "lll",
            "x-honeycomb-team": "logs_key",
            "x-otlp-version": honeycombLibraryVersion
        ], config.logsHeaders)

        XCTAssertEqual(40.0, config.tracesTimeout)
        XCTAssertEqual(50.0, config.metricsTimeout)
        XCTAssertEqual(60.0, config.logsTimeout)

        XCTAssertEqual(OTLPProtocol.grpc, config.tracesProtocol)
        XCTAssertEqual(OTLPProtocol.grpc, config.metricsProtocol)
        XCTAssertEqual(OTLPProtocol.grpc, config.logsProtocol)
        
        XCTAssertTrue(config.debug)
        XCTAssertEqual(42, config.sampleRate)
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
            "OTEL_EXPORTER_OTLP_TRACES_HEADERS": "foo=bar2,merged=yes"
        ]
        let source = HoneycombOptionsSource(info: data)
        let config = try HoneycombOptions.Builder(source: source).build()

        let expected = [
            "baz": "qux",
            "foo": "bar2",
            "merged": "yes",
            "x-honeycomb-team": "key",
            "x-otlp-version": honeycombLibraryVersion
        ]
        XCTAssertEqual(expected, config.tracesHeaders)
    }

    func testServiceNameTakesPrecedence() throws {
        let data = [
            "HONEYCOMB_API_KEY": "key",
            "OTEL_SERVICE_NAME": "explicit",
            "OTEL_RESOURCE_ATTRIBUTES": "service.name=resource"
        ]
        let source = HoneycombOptionsSource(info: data)
        let config = try HoneycombOptions.Builder(source: source).build()

        XCTAssertEqual("explicit", config.serviceName)
        let expectedResources = [
            "service.name": "resource",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion
        ]
        XCTAssertEqual(expectedResources, config.resourceAttributes)
    }
    
    func testServiceNameFromResourceAttributes() throws {
        let data = [
            "HONEYCOMB_API_KEY": "key",
            "OTEL_RESOURCE_ATTRIBUTES": "service.name=better"
        ]
        let source = HoneycombOptionsSource(info: data)
        let config = try HoneycombOptions.Builder(source: source).build()

        XCTAssertEqual("better", config.serviceName)
        let expectedResources = [
            "service.name": "better",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion
        ]
        XCTAssertEqual(expectedResources, config.resourceAttributes)
    }
    
    func testServiceNameDefault() throws {
        let data: [String:String] = [
            "HONEYCOMB_API_KEY": "key"
        ]
        let source = HoneycombOptionsSource(info: data)
        let config = try HoneycombOptions.Builder(source: source).build()

        XCTAssertEqual("unknown_service", config.serviceName)
        let expectedResources = [
            "service.name": "unknown_service",
            "honeycomb.distro.version": honeycombLibraryVersion,
            "honeycomb.distro.runtime_version": runtimeVersion
        ]
        XCTAssertEqual(expectedResources, config.resourceAttributes)
    }
    
    func testMalformedKeyValueString() throws {
        XCTAssertThrowsError(try parseKeyValueList("foo=bar,baz")) { e in
            XCTAssert(e is HoneycombOptionsError)
            XCTAssertEqual(e as? HoneycombOptionsError, .malformedKeyValueString("baz"))
        }
    }
    
    func testMissingAPIKey() throws {
        let data: [String:String] = [:]
        let source = HoneycombOptionsSource(info: data)

        XCTAssertThrowsError(try HoneycombOptions.Builder(source: source).build()) { e in
            XCTAssert(e is HoneycombOptionsError)
            XCTAssertEqual(e as? HoneycombOptionsError, .missingAPIKey("missing API key: call setAPIKey()"))
        }
    }
    
    func testIncorrectType() throws {
        let data = [
            "OTEL_EXPORTER_OTLP_TIMEOUT": "not a number"
        ]
        let source = HoneycombOptionsSource(info: data)

        XCTAssertThrowsError(try HoneycombOptions.Builder(source: source).build()) { e in
            XCTAssert(e is HoneycombOptionsError)
            XCTAssertEqual(e as? HoneycombOptionsError, .incorrectType("OTEL_EXPORTER_OTLP_TIMEOUT"))
        }
    }

    func testUnsupportedExporter() throws {
        let data = [
            "OTEL_TRACES_EXPORTER": "invalid-exporter"
        ]
        let source = HoneycombOptionsSource(info: data)

        XCTAssertThrowsError(try HoneycombOptions.Builder(source: source).build()) { e in
            XCTAssert(e is HoneycombOptionsError)
            XCTAssertEqual(e as? HoneycombOptionsError,
                           .unsupportedExporter("unsupported exporter invalid-exporter for OTEL_TRACES_EXPORTER"))
        }
    }

    func testUnsupportedProtocol() throws {
        let data = [
            "OTEL_EXPORTER_OTLP_PROTOCOL": "invalid-protocol"
        ]
        let source = HoneycombOptionsSource(info: data)

        XCTAssertThrowsError(try HoneycombOptions.Builder(source: source).build()) { e in
            XCTAssert(e is HoneycombOptionsError)
            XCTAssertEqual(e as? HoneycombOptionsError, .unsupportedProtocol("invalid protocol invalid-protocol"))
        }
    }
}
