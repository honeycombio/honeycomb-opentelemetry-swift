import Foundation
import XCTest

@testable import Honeycomb

final class URLSessionRequestFilterTests: XCTestCase {
    private let appRequest = URLRequest(url: URL(string: "https://api.example.com/cart")!)
    private let sessionReplayRequest = URLRequest(url: URL(string: "https://quantum.example.net/")!)

    private var previousFilter: ((URLRequest) -> Bool)?

    override func setUp() {
        super.setUp()
        previousFilter = urlSessionRequestFilter
    }

    /// Puts the filter back, since it is process-global and Honeycomb.configure also sets it.
    override func tearDown() {
        urlSessionRequestFilter = previousFilter
        super.tearDown()
    }

    func testBuilderPassesFilterToOptions() throws {
        let options = try HoneycombOptions.Builder()
            .setAPIKey("test-key")
            .setURLSessionRequestFilter { $0.url?.host != "quantum.example.net" }
            .build()

        let filter = try XCTUnwrap(options.urlSessionRequestFilter)
        XCTAssertTrue(filter(appRequest))
        XCTAssertFalse(filter(sessionReplayRequest))
    }

    func testNoFilterOrSpanNameProviderByDefault() throws {
        let options = try HoneycombOptions.Builder().setAPIKey("test-key").build()
        XCTAssertNil(options.urlSessionRequestFilter)
        XCTAssertNil(options.urlSessionSpanNameProvider)
    }

    func testInstrumentsEverythingWithoutFilter() {
        urlSessionRequestFilter = nil
        XCTAssertTrue(shouldInstrument(appRequest))
        XCTAssertTrue(shouldInstrument(sessionReplayRequest))
    }

    func testSkipsOnlyRequestsTheFilterRejects() {
        urlSessionRequestFilter = { $0.url?.host != "quantum.example.net" }
        XCTAssertTrue(shouldInstrument(appRequest))
        XCTAssertFalse(shouldInstrument(sessionReplayRequest))
    }

    /// The SDK's own export requests must never be traced, even if the app's filter allows them.
    func testNeverInstrumentsOTLPRequests() {
        urlSessionRequestFilter = { _ in true }
        var request = appRequest
        request.setValue("1", forHTTPHeaderField: "x-otlp-version")
        XCTAssertFalse(shouldInstrument(request))
    }
}
