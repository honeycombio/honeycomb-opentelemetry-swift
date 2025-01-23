import Foundation

internal let sessionIdKey: String = "session.id"
internal let sessionStartTimeKey: String = "session.startTime"
internal let suiteName: String = "io.honeycomb.opentelemetry.swift"

struct SessionStorage {
    let userDefaults = UserDefaults(suiteName: suiteName)!

    func read() -> Session {
        guard let id = userDefaults.string(forKey: sessionIdKey),
            let startTimestamp = userDefaults.object(forKey: sessionStartTimeKey)
                as? Date
        else {
            // If the saves session is garbo, return sentienel value to indicate there's no existing session
            return defaulSession
        }

        return Session(id: id, startTimestamp: startTimestamp)
    }

    func save(session: Session) {
        userDefaults.set(session.id, forKey: sessionIdKey)
        userDefaults.set(session.startTimestamp, forKey: sessionStartTimeKey)
    }
    func clear() {
        userDefaults.set(defaulSession.id, forKey: sessionIdKey)
        userDefaults.set(
            defaulSession.startTimestamp,
            forKey: sessionStartTimeKey
        )

    }
}
