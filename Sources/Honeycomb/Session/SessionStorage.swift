import Foundation

private let sessionIdKey: String = "session.id"
private let sessionStartTimeKey: String = "session.startTime"

// A set of utility functions for reading and saving a Session object to persistent storage
struct SessionStorage {
    func read() -> HoneycombSession? {
        guard let id = UserDefaults.standard.string(forKey: sessionIdKey),
            let startTimestamp = UserDefaults.standard.object(forKey: sessionStartTimeKey)
                as? Date
        else {
            return nil
        }

        return HoneycombSession(id: id, startTimestamp: startTimestamp)
    }

    func save(session: HoneycombSession) {
        UserDefaults.standard.set(session.id, forKey: sessionIdKey)
        UserDefaults.standard.set(session.startTimestamp, forKey: sessionStartTimeKey)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: sessionIdKey)
        UserDefaults.standard.removeObject(forKey: sessionStartTimeKey)
    }
}
