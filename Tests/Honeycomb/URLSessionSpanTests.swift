import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import Honeycomb

final class URLSessionSpanTests: XCTestCase {
    private var previousTracerProvider: TracerProvider?
    private var previousSpanNameProvider: ((URLRequest) -> String?)?

    /// Registers a provider whose spans can be read back, since the default one records nothing.
    override func setUp() {
        super.setUp()
        previousTracerProvider = OpenTelemetry.instance.tracerProvider
        previousSpanNameProvider = urlSessionSpanNameProvider
        OpenTelemetry.registerTracerProvider(tracerProvider: TracerProviderBuilder().build())
    }

    override func tearDown() {
        if let previousTracerProvider {
            OpenTelemetry.registerTracerProvider(tracerProvider: previousTracerProvider)
        }
        urlSessionSpanNameProvider = previousSpanNameProvider
        super.tearDown()
    }

    private func spanData(_ span: Span) throws -> SpanData {
        try XCTUnwrap((span as? ReadableSpan)?.toSpanData())
    }

    private func makeSpan(_ url: String, method: String = "GET") -> Span {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        return createSpan(from: request)
    }

    // MARK: span names

    func testSpansAreNamedAfterTheMethodByDefault() throws {
        urlSessionSpanNameProvider = nil
        XCTAssertEqual(try spanData(makeSpan("https://api.example.com/products/42")).name, "GET")
    }

    func testSpanNameProviderNamesSpans() throws {
        urlSessionSpanNameProvider = { request in
            "\(request.httpMethod ?? "UNKNOWN") /products/:id"
        }
        let span = makeSpan("https://api.example.com/products/42", method: "POST")
        XCTAssertEqual(try spanData(span).name, "POST /products/:id")
    }

    /// The provider can decline to name a request, and that request keeps the default name.
    func testSpanNameProviderReturningNilFallsBackToMethod() throws {
        urlSessionSpanNameProvider = { $0.url?.path == "/products/42" ? "product" : nil }
        let named = makeSpan("https://api.example.com/products/42")
        XCTAssertEqual(try spanData(named).name, "product")
        XCTAssertEqual(try spanData(makeSpan("https://api.example.com/cart")).name, "GET")
    }

    func testBuilderPassesSpanNameProviderToOptions() throws {
        let options = try HoneycombOptions.Builder()
            .setAPIKey("test-key")
            .setURLSessionSpanNameProvider { _ in "named" }
            .build()
        let request = URLRequest(url: URL(string: "https://api.example.com/")!)
        XCTAssertEqual(options.urlSessionSpanNameProvider?(request), "named")
    }

    // MARK: response status

    private func responseStatus(_ code: Int) throws -> Status {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com/")!,
            statusCode: code,
            httpVersion: nil,
            headerFields: nil
        )!
        let span = makeSpan("https://api.example.com/")
        updateSpan(span, with: response)
        return try spanData(span).status
    }

    func testClientAndServerErrorResponsesSetErrorStatus() throws {
        for code in [400, 404, 500, 503] {
            XCTAssertEqual(try responseStatus(code), .error(description: String(code)), "\(code)")
        }
    }

    /// 399 is the boundary: redirects and everything below are not errors.
    func testSuccessAndRedirectResponsesLeaveStatusUnset() throws {
        for code in [200, 204, 301, 304, 399] {
            XCTAssertEqual(try responseStatus(code), .unset, "\(code)")
        }
    }

    func testErrorResponseStillRecordsStatusCode() throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com/")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )!
        let span = makeSpan("https://api.example.com/")
        updateSpan(span, with: response)
        XCTAssertEqual(
            try spanData(span).attributes[SemanticAttributes.httpResponseStatusCode.rawValue],
            .int(404)
        )
    }
}
