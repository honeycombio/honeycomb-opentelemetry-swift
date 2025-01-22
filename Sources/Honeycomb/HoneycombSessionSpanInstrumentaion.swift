import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

//TODO: not one giant file, probaly
protocol Session {
    var id: String { get }
    var startTimestamp: Date { get }

    init(id: String, startTimestamp: Date)
}

// TODO: Override equals so that we can s1 == s2 ?
func compareSesh(s1: any Session, s2: any Session) -> Bool {
    return s1.id == s2.id && s1.startTimestamp == s2.startTimestamp
}

class DefaultSession: Session {
    let id: String
    let startTimestamp: Date

    static var none: any Session = DefaultSession(id: "", startTimestamp: Date.distantPast)

    required public init(id: String, startTimestamp: Date) {
        self.id = id
        self.startTimestamp = startTimestamp
    }
}

protocol SessionProvider {
    var sessionId: String { get }
}

protocol SessionManager:
    SessionProvider
{}

public class SessionStorage {
    // TODO: Is there a convention for keys?
    public static var sessionIdKey: String = "session.id"
    public static var suiteName: String = "io.honeycomb.opentelemetry.swift"
    let userDefaults = UserDefaults(suiteName: SessionStorage.suiteName)!

    func read() -> String {
        let id = userDefaults.string(forKey: SessionStorage.sessionIdKey) ?? ""
        return id
    }
    func save(session: Session) {
        userDefaults.set(session.id, forKey: SessionStorage.sessionIdKey)
    }
    func clear() {
        userDefaults.set("", forKey: SessionStorage.sessionIdKey)
    }
}

public class HoneycombSessionManager: SessionManager {
    private var currentSession: Session = DefaultSession.none

    private var debug: Bool
    private var sessionLifetimeSeconds: TimeInterval
    private var sessionIdGenerator: () -> String
    private var sessionStorage: SessionStorage
    private var dateProvider: () -> Date

    // Default providers/generators
    @usableFromInline static var defaultTimeout: TimeInterval { 60 * 60 * 4 }

    static func defaultSessionIdGenerator() -> String {
        TraceId.random().hexString
    }
    static func defaultDateProvider() -> Date {
        Date()
    }

    init(
        sessionStorage: SessionStorage = SessionStorage(),
        debug: Bool = false,
        sessionLifetimeSeconds: TimeInterval = defaultTimeout,
        sessionIdGenerator: @escaping () -> String = HoneycombSessionManager
            .defaultSessionIdGenerator,
        dateProvider: @escaping () -> Date = HoneycombSessionManager.defaultDateProvider
    ) {
        self.sessionStorage = sessionStorage
        self.sessionIdGenerator = sessionIdGenerator
        self.dateProvider = dateProvider
        self.sessionLifetimeSeconds = sessionLifetimeSeconds
        self.debug = debug
    }

    func isSessionExpired() -> Bool {
        let elapsedTime: TimeInterval = dateProvider()
            .timeIntervalSince(currentSession.startTimestamp)
        return elapsedTime >= sessionLifetimeSeconds
    }

    var sessionId: String {
        // If the session is default session make a new one
        if compareSesh(s1: currentSession, s2: DefaultSession.NONE) {
            let newSession = DefaultSession(
                id: sessionIdGenerator(),
                startTimestamp: dateProvider()
            )
            if debug {
                print("🐝: HoneycombSessionManager: No active session, creating session.")
                dump(newSession, name: " 🐝: Current Sesion")
            }
            self.currentSession = newSession
        }

        // If the session timeout has elapsed, make a new one
        if isSessionExpired() {
            let previousSession = currentSession
            let newSession = DefaultSession(
                id: sessionIdGenerator(),
                startTimestamp: dateProvider()
            )
            if debug {
                print(
                    "🐝: HoneycombSessionManager: Session timeout after \(sessionLifetimeSeconds) seconds elapsed, creating new session."
                )
                dump(previousSession, name: "🐝:  Previous Sesion")
                dump(newSession, name: " 🐝: Current Sesion")
            }
            self.currentSession = newSession
        }

        // Update the session ID
        sessionStorage.save(session: currentSession)
        // Always return the current session's id
        return self.currentSession.id
    }
}

public struct HoneycombSessionIdSpanProcessor: SpanProcessor {
    public let isStartRequired = true
    public let isEndRequired = false
    private var sessionManager: HoneycombSessionManager

    public init(
        debug: Bool = false,
        sessionLifetimeSeconds: TimeInterval = HoneycombSessionManager.defaultTimeout
    ) {
        self.sessionManager = HoneycombSessionManager(
            debug: debug,
            sessionLifetimeSeconds: sessionLifetimeSeconds
        )
    }

    public func onStart(
        parentContext: SpanContext?,
        span: any ReadableSpan
    ) {
        span.setAttribute(
            key: "session.id",
            value: sessionManager.sessionId
        )
    }

    public func onEnd(span: any ReadableSpan) {}

    public func shutdown(explicitTimeout: TimeInterval? = nil) {}

    public func forceFlush(timeout: TimeInterval? = nil) {}
}
