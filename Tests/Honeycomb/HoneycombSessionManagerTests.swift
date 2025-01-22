import XCTest

@testable import Honeycomb

class MockDateProvider {
    var advanedBy: TimeInterval = 0

    func advanedBy(by: TimeInterval = TimeInterval(60 * 60 * 6)) {
        advanedBy = by
    }

    func provider() -> Date {
        return Date().advanced(by: advanedBy)
    }
}

final class HoneycombSessionManagerTests: XCTestCase {
    var sessionManager: HoneycombSessionManager!
    var storage = SessionStorage()

    override func setUp() {
        super.setUp()
        storage.clear()
        sessionManager = HoneycombSessionManager(sessionStorage: storage, debug: true)

    }

    override func tearDown() {
        storage.clear()
        super.tearDown()
    }

    func testSessionCreationOnStartup() {
        let sessionIdBefore = storage.read()
        XCTAssert(sessionIdBefore.isEmpty, "The default session ID should be empty.")

        let sessionIdAfter = sessionManager.sessionId
        XCTAssertNotEqual(
            sessionIdBefore,
            sessionIdAfter,
            "A new session should be created"
        )
        XCTAssert(!sessionIdAfter.isEmpty, "A new session ID should not be empty.")

        // The new sessionId should be stored
        let storedSessionId = storage.read()
        XCTAssert(!storedSessionId.isEmpty, "The stored session ID should not be empty.")
        XCTAssertEqual(
            storedSessionId,
            sessionIdAfter,
            "the stored session ID should match the newly created one."
        )

    }

    func testSessionIdShouldBeStableOnSubsequentRereads() {
        let sessionId = sessionManager.sessionId
        XCTAssertNotEqual(
            sessionId,
            "",
            "A non-empty session ID exists"
        )
        XCTAssert(!sessionId.isEmpty, "A non-empty session ID exists")

        let storedSessionId = storage.read()
        XCTAssert(!storedSessionId.isEmpty, "The stored session ID should not be empty.")
        XCTAssertEqual(
            storedSessionId,
            sessionId,
            "the stored session ID should match the newly created one."
        )

        let reReadSessionId = sessionManager.sessionId
        XCTAssertEqual(
            sessionId,
            reReadSessionId,
            "Subsequent reads should yield the same session ID."
        )

    }

    func testSessionIDShouldChangeAfterTimeout() {
        let dateProvider = MockDateProvider()

        sessionManager = HoneycombSessionManager(
            sessionStorage: storage,
            debug: true,
            dateProvider: dateProvider.provider
        )
        let sessionId = sessionManager.sessionId
        XCTAssertNotEqual(
            sessionId,
            "",
            "A non-empty session ID exists"
        )
        XCTAssert(!sessionId.isEmpty, "A non-empty session ID exists")

        let storedSessionId = storage.read()
        XCTAssert(!storedSessionId.isEmpty, "The stored session ID should not be empty.")
        XCTAssertEqual(
            storedSessionId,
            sessionId,
            "the stored session ID should match the newly created one."
        )

        let readOne = sessionManager.sessionId
        XCTAssertEqual(
            sessionId,
            readOne,
            "Subsequent reads should yield the same session ID."
        )
        // Jump forward in time.
        dateProvider.advanedBy()

        let readTwo = sessionManager.sessionId
        XCTAssert(!storedSessionId.isEmpty, "The stored session ID should not be empty.")
        XCTAssertNotEqual(
            sessionId,
            readTwo,
            "After timeout, a new session ID should be generated."
        )
    }
}
