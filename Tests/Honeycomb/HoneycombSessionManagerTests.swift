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
    var storage: SessionStorage!
    var sessionLifetimeSeconds = TimeInterval(60 * 60 * 4)
    override func setUp() {
        super.setUp()
        storage = SessionStorage()
        sessionManager = HoneycombSessionManager(
            sessionStorage: storage,
            debug: true,
            sessionLifetimeSeconds: sessionLifetimeSeconds
        )
    }

    override func tearDown() {
        storage.clear()
        super.tearDown()
    }

    func testSessionCreationOnStartup() {
        guard let sessionIdBefore = storage.read()?.id else {
            XCTFail("No session found in storage.")
            return
        }
        XCTAssert(sessionIdBefore.isEmpty, "The default session ID should be empty.")

        let sessionIdAfter = sessionManager.sessionId
        XCTAssertNotEqual(
            sessionIdBefore,
            sessionIdAfter,
            "A new session should be created"
        )
        XCTAssert(!sessionIdAfter.isEmpty, "A new session ID should not be empty.")

        // The new sessionId should be stored
        guard let storedSessionId = storage.read()?.id else {
            XCTFail("No session found in storage.")
            return
        }
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

        guard  let storedSessionId = storage.read()?.id else {
            XCTFail(
                "No session found in storage."
            )
            return
        }
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
            sessionLifetimeSeconds: sessionLifetimeSeconds,
            dateProvider: dateProvider.provider

        )
        let sessionId = sessionManager.sessionId
        XCTAssertNotEqual(
            sessionId,
            "",
            "A non-empty session ID exists"
        )
        XCTAssert(!sessionId.isEmpty, "A non-empty session ID exists")

        guard let storedSessionId = storage.read()?.id else {
            XCTFail(
                "No session found in storage."
            )
            return
        }
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

    func testSessionIDShouldRefreshOnStartup() {
        let dateProvider = MockDateProvider()

        sessionManager = HoneycombSessionManager(
            sessionStorage: storage,
            debug: true,
            sessionLifetimeSeconds: sessionLifetimeSeconds,
            dateProvider: dateProvider.provider
        )
        let sessionId = sessionManager.sessionId
        guard let storedSessionIdOne = storage.read()?.id else {
            XCTFail(
                "No session found in storage."
            )
            return
        }

        XCTAssert(!sessionId.isEmpty, "A non-empty session ID is return from SessionManager")
        XCTAssert(
            !storedSessionIdOne.isEmpty,
            "A non-empty session ID is return from SessionStorage"
        )
        XCTAssertEqual(
            storedSessionIdOne,
            sessionId,
            "the stored session ID should match the newly created one."
        )

        // Instantiate a new sessionManager to simulate app restart within timeout
        let sessionManager2 = HoneycombSessionManager(
            sessionStorage: storage,
            debug: true,
            sessionLifetimeSeconds: sessionLifetimeSeconds,
            dateProvider: dateProvider.provider
        )

        let sessionIdTwo = sessionManager2.sessionId
        guard let storedSessionIdTwo = storage.read()?.id else {
            XCTFail(
                "No session found in storage."
            )
            return
        }

        XCTAssert(!sessionIdTwo.isEmpty, "A non-empty session ID is return from SessionManager")
        XCTAssert(
            !storedSessionIdTwo.isEmpty,
            "A non-empty session ID is return from SessionStorage"
        )
        XCTAssertEqual(
            sessionIdTwo,
            storedSessionIdTwo,
            "the stored session ID should match the newly created one."
        )

        XCTAssertNotEqual(
            sessionId,
            sessionIdTwo,
            "the session ID should not match the previously fetched one."
        )
        XCTAssertNotEqual(
            storedSessionIdOne,
            storedSessionIdTwo  //,
            //            "the session ID should not match the stored one."
        )
        XCTAssertEqual(
            sessionIdTwo,
            storedSessionIdTwo,
            "the current session ID should match the current stored one."
        )
    }
}
