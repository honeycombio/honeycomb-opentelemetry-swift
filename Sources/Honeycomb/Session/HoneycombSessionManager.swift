import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

internal protocol SessionProvider {
    var sessionId: String { get }
}

internal protocol SessionManager:
    SessionProvider
{}

extension Notification.Name {
    static let sessionStarted = Notification.Name("io.honeycomb.app.session.started")
}

extension Notification.Name {
    static let sessionEnded = Notification.Name("io.honeycomb.app.session.ended")
}

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
            if previousSession != nil {
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
        var userInfo: [String: Any] = [:]
        userInfo["previousSession"] = previousSession ?? nil
        NotificationCenter.default.post(
            name: Notification.Name.sessionStarted,
            object: newSession,
            userInfo: userInfo
        )

    }

    func onSessionEnded(session: Session) {
        if debug {
            print(
                "🐝: HoneycombSessionManager: Session Ended."
            )
            dump(session, name: "Session")
        }
        NotificationCenter.default.post(name: Notification.Name.sessionEnded, object: session)
    }

}
