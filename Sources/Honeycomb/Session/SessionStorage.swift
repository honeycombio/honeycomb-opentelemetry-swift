import Foundation

internal let sessionIdKey: String = "session.id"
internal let sessionStartTimeKey: String = "session.startTime"

struct SessionStorage {
    let userDefaults = UserDefaults.standard 

    func read() -> Session? {
        guard let id = userDefaults.string(forKey: sessionIdKey),
            let startTimestamp = userDefaults.object(forKey: sessionStartTimeKey)
                as? Date
        else {
            // If the saves session is garbo, return sentienel value to indicate there's no existing session
            return nil
        }

        return Session(id: id, startTimestamp: startTimestamp)
    }

    func save(session: Session) {
        userDefaults.set(session.id, forKey: sessionIdKey)
        userDefaults.set(session.startTimestamp, forKey: sessionStartTimeKey)
    }

    func clear() {
        userDefaults.set("", forKey: sessionIdKey)
        userDefaults.set(
            Date.distantPast,
            forKey: sessionStartTimeKey
        )

    }
}
