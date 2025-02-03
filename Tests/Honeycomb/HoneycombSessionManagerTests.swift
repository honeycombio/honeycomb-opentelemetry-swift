import XCTest

@testable import Honeycomb

class MockDateProvider {
    var elapsed: TimeInterval = 0

    func advance(by: TimeInterval = TimeInterval(60 * 60 * 6)) {
        elapsed += by
    }

    func provider() -> Date {
        return Date().advanced(by: elapsed)
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
            debug: true,
            sessionLifetimeSeconds: sessionLifetimeSeconds
        )
    }

    override func tearDown() {
        storage.clear()
        super.tearDown()
    }

    func testSessionCreationOnStartup() {
        let sessionBeforeId = storage.read()?.id
        XCTAssertNil(sessionBeforeId, "Session should be cleared on startup.")
        let sessionIdAfter = sessionManager.sessionId
        XCTAssertNotNil(
            sessionIdAfter,
            "A new session should be created"
        )
        XCTAssert(!sessionIdAfter.isEmpty, "A new session ID should not be empty.")

        // The new sessionId should be stored
        let storedSessionId = storage.read()?.id
        XCTAssertEqual(
            storedSessionId,
            sessionIdAfter,
            "the stored session ID should match the newly created one."
        )

    }

    func testSessionIdShouldBeStableOnSubsequentRereads() {
        let sessionId = sessionManager.sessionId
        let storedSessionId = storage.read()?.id

        XCTAssertNotNil(sessionId, "A non-empty session ID exists")
        XCTAssertNotNil(storedSessionId, "The stored session ID should not be empty.")
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

        let storedSessionId = storage.read()?.id
        XCTAssertNotNil(storedSessionId, "The stored session ID should not be empty.")
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
        dateProvider.advance()

        let readTwo = sessionManager.sessionId
        XCTAssertNotEqual(
            sessionId,
            readTwo,
            "After timeout, a new session ID should be generated."
        )
    }

    func testSessionIDShouldRefreshOnStartup() {
        let dateProvider = MockDateProvider()

        sessionManager = HoneycombSessionManager(
            debug: true,
            sessionLifetimeSeconds: sessionLifetimeSeconds,
            dateProvider: dateProvider.provider
        )
        let sessionId = sessionManager.sessionId
        let storedSessionIdOne = storage.read()?.id

        XCTAssert(!sessionId.isEmpty, "A non-empty session ID is return from SessionManager")
        XCTAssertNotNil(storedSessionIdOne, "A non-empty session ID is return from SessionStorage")
        XCTAssertEqual(
            storedSessionIdOne,
            sessionId,
            "the stored session ID should match the newly created one."
        )

        // Instantiate a new sessionManager to simulate app restart within timeout
        let sessionManager2 = HoneycombSessionManager(
            debug: true,
            sessionLifetimeSeconds: sessionLifetimeSeconds,
            dateProvider: dateProvider.provider
        )

        let sessionIdTwo = sessionManager2.sessionId
        let storedSessionIdTwo = storage.read()?.id
        XCTAssertNotNil(sessionIdTwo, "A non-empty session ID is return from SessionManager")
        XCTAssertEqual(
            sessionIdTwo,
            storedSessionIdTwo,
            "the stored session ID should match the newly created one."
        )

        XCTAssertNotEqual(sessionId, sessionIdTwo)
        XCTAssertNotEqual(storedSessionIdOne, storedSessionIdTwo)
        XCTAssertEqual(
            sessionIdTwo,
            storedSessionIdTwo,
            "the current session ID should match the current stored one."
        )
    }

    func testOnSessionStartedOnStartup() {
        let expectation = self.expectation(forNotification: .sessionStarted, object: nil) {
            notification in
            if let session = notification.object as? HoneycombSession {
                XCTAssertNil(notification.userInfo!["previousSession"])
                XCTAssertNotNil(session.id)
                XCTAssertNotNil(session.startTimestamp)
                return true
            }
            return false
        }

        _ = sessionManager.sessionId

        wait(for: [expectation], timeout: 1)
    }

    func testOnSessionEndedOnStartupShouldNotBeEmitted() {
        let expectation = self.expectation(
            forNotification: .sessionEnded,
            object: nil,
            handler: nil
        )
        expectation.isInverted = true

        _ = sessionManager.sessionId
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(
            expectation.expectedFulfillmentCount > 0,
            "Notification '.sessionEnded' was unexpectedly posted when it should not have been."
        )
    }

    func testOnSessionStartedAfterTimeout() {
        let dateProvider = MockDateProvider()
        sessionManager = HoneycombSessionManager(
            debug: true,
            sessionLifetimeSeconds: sessionLifetimeSeconds,
            dateProvider: dateProvider.provider

        )
        var startNotifications: [Notification] = []
        let expectation = self.expectation(forNotification: .sessionStarted, object: nil) {
            notification in
            startNotifications.append(notification)
            return startNotifications.count == 2
        }
        var endNotifications: [Notification] = []

        let endExpectation = self.expectation(forNotification: .sessionEnded, object: nil) {
            notification in
            endNotifications.append(notification)
            return endNotifications.count == 1
        }

        _ = sessionManager.sessionId
        dateProvider.advance()
        _ = sessionManager.sessionId

        wait(for: [expectation, endExpectation], timeout: 1)
        guard let session = startNotifications.last?.object as? HoneycombSession else {
            XCTFail("Session not present on start session notification")
            return
        }
        XCTAssertNotNil(session.id)
        XCTAssertNotNil(session.startTimestamp)

        guard
            let previousSession = startNotifications.last?.userInfo?["previousSession"]
                as? HoneycombSession
        else {
            XCTFail("Previous session not present on start session notification")
            return
        }
        XCTAssertNotNil(previousSession.id)
        XCTAssertNotNil(previousSession.startTimestamp)

        guard let endedSession = endNotifications.last?.object as? HoneycombSession else {
            XCTFail("Session not present on end session notification")
            return
        }
        XCTAssertNotNil(endedSession.id)
        XCTAssertNotNil(endedSession.startTimestamp)

        XCTAssertEqual(
            previousSession,
            endedSession,
            "Previous session should match the ended session"
        )
    }
}
