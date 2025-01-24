import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

internal protocol SessionProvider {
    var sessionId: String { get }
}

internal protocol SessionObserver {
    func onSessionStarted(
        newSession: Session,
        previousSession: Session?
    )

    func onSessionEnded(session: Session)
}

internal protocol SessionManager:
    SessionProvider,
    SessionObserver
{}

public class HoneycombSessionManager: SessionManager {
    private var sessionStorage: SessionStorage
    private var currentSession: Session?
    private var debug: Bool
    private var sessionLifetimeSeconds: TimeInterval

    private var sessionIdProvider: () -> String
    private var dateProvider: () -> Date

    init(
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
        self.sessionStorage = SessionStorage()
        self.sessionIdProvider = sessionIdGenerator
        self.dateProvider = dateProvider
        self.sessionLifetimeSeconds = sessionLifetimeSeconds
        self.debug = debug
        self.currentSession = nil
        self.sessionStorage.clear()
    }

    var isSessionExpired: Bool {
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
                id: sessionIdProvider(),
                startTimestamp: dateProvider()
            )
            if debug {
                print("🐝: HoneycombSessionManager: No active session, creating session.")
                onSessionStarted(newSession: newSession, previousSession: nil)
            }
            self.currentSession = newSession
        } else
        // If the session timeout has elapsed, make a new one
        if isSessionExpired {
            if debug {
                print(
                    "🐝: HoneycombSessionManager: Session timeout after \(sessionLifetimeSeconds) seconds elapsed, creating new session."
                )
            }
            let previousSession = self.currentSession
            let newSession = Session(
                id: sessionIdProvider(),
                startTimestamp: dateProvider()
            )

            onSessionStarted(newSession: newSession, previousSession: previousSession)
            if(previousSession != nil){
                onSessionEnded(session: previousSession!)
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

    func onSessionStarted(newSession: Session, previousSession: Session?) {
        if debug {
            print(
                "🐝: HoneycombSessionManager: Creating new session."
            )
            dump(previousSession, name: "Previous session")
            dump(newSession, name: "Current session")
        }
    }

    func onSessionEnded(session: Session) {
        if debug {
            print(
                "🐝: HoneycombSessionManager: Session Ended."
            )
            dump(session, name: "Session")
        }
    }

}
