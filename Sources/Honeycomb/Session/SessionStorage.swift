import Foundation

private let sessionIdKey: String = "session.id"
private let sessionStartTimeKey: String = "session.startTime"

// A set of utility functions for reading and saving a Session object to persistent storage
struct SessionStorage {
    func read() -> Session? {
        guard let id = UserDefaults.standard.string(forKey: sessionIdKey),
            let startTimestamp = UserDefaults.standard.object(forKey: sessionStartTimeKey)
                as? Date
        else {
            // If the saves session is garbo, return sentienel value to indicate there's no existing session
            return nil
        }

        return Session(id: id, startTimestamp: startTimestamp)
    }

    func save(session: Session) {
        UserDefaults.standard.set(session.id, forKey: sessionIdKey)
        UserDefaults.standard.set(session.startTimestamp, forKey: sessionStartTimeKey)
    }

    func clear() {
        UserDefaults.standard.set("", forKey: sessionIdKey)
        UserDefaults.standard.set(
            Date.distantPast,
            forKey: sessionStartTimeKey
        )
    }
}
