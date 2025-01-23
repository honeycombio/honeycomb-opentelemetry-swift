import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

internal protocol SessionProvider {
    var sessionId: String { get }
}

internal protocol SessionManager:
    SessionProvider
{}

internal func defaultSessionIdGenerator() -> String {
    TraceId.random().hexString
}

internal func defaultDateProvider() -> Date {
    Date()
}

public class HoneycombSessionManager: SessionManager {
    private var currentSession: Session = defaulSession

    private var debug: Bool
    private var sessionLifetimeSeconds: TimeInterval
    private var sessionIdGenerator: () -> String
    private var sessionStorage: SessionStorage
    private var dateProvider: () -> Date

    init(
        sessionStorage: SessionStorage = SessionStorage(),
        debug: Bool = false,
        sessionLifetimeSeconds: TimeInterval,
        sessionIdGenerator: @escaping () -> String =
            defaultSessionIdGenerator,
        dateProvider: @escaping () -> Date = defaultDateProvider
    ) {

        self.sessionStorage = sessionStorage
        self.sessionIdGenerator = sessionIdGenerator
        self.dateProvider = dateProvider
        self.sessionLifetimeSeconds = sessionLifetimeSeconds
        self.debug = debug
        self.currentSession = defaulSession
        self.sessionStorage.save(session: self.currentSession)
    }

    func isSessionExpired() -> Bool {
        let elapsedTime: TimeInterval = dateProvider()
            .timeIntervalSince(currentSession.startTimestamp)
        return elapsedTime >= sessionLifetimeSeconds
    }

    var sessionId: String {
        // If the session is default session make a new one
        if currentSession == defaulSession {
            let newSession = Session(
                id: sessionIdGenerator(),
                startTimestamp: dateProvider()
            )
            if debug {
                print("🐝: HoneycombSessionManager: No active session, creating session.")
                dump(newSession, name: "Current session")
            }
            self.currentSession = newSession
        }

        // If the session timeout has elapsed, make a new one
        if isSessionExpired() {
            let previousSession = currentSession
            let newSession = Session(
                id: sessionIdGenerator(),
                startTimestamp: dateProvider()
            )
            if debug {
                print(
                    "🐝: HoneycombSessionManager: Session timeout after \(sessionLifetimeSeconds) seconds elapsed, creating new session."
                )
                dump(previousSession, name: "Previous session")
                dump(newSession, name: "Current session")
            }
            self.currentSession = newSession
        }

        // Update the session ID
        sessionStorage.save(session: currentSession)
        // Always return the current session's id
        return self.currentSession.id
    }
}
