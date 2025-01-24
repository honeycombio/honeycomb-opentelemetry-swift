import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

internal protocol SessionProvider {
    var sessionId: String { get }
}

internal protocol SessionManager:
    SessionProvider
{}

public class HoneycombSessionManager: SessionManager {
    private var currentSession: Session?
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
            {
                TraceId.random().hexString
            },
        dateProvider: @escaping () -> Date = {
            Date()
        }
    ) {

        self.sessionStorage = sessionStorage
        self.sessionIdGenerator = sessionIdGenerator
        self.dateProvider = dateProvider
        self.sessionLifetimeSeconds = sessionLifetimeSeconds
        self.debug = debug
        self.currentSession = nil
        self.sessionStorage.clear()
    }

    func isSessionExpired() -> Bool {
        guard let currentSession = currentSession else {
            return true
        }
        let elapsedTime: TimeInterval = dateProvider()
            .timeIntervalSince(currentSession.startTimestamp)
        return elapsedTime >= sessionLifetimeSeconds
    }

    var sessionId: String {
        // If there is no current session make a new one
        if self.currentSession == nil {
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
            let previousSession = self.currentSession
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

        guard let currentSession = self.currentSession else {
            return ""
        }
        // Always return the current session's id
        sessionStorage.save(session: currentSession)
        return currentSession.id
    }

}
