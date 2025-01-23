import Foundation

internal struct Session: Equatable {
    let id: String
    let startTimestamp: Date

    internal static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs.id == rhs.id && lhs.startTimestamp == rhs.startTimestamp
    }

    init(id: String, startTimestamp: Date) {
        self.id = id
        self.startTimestamp = startTimestamp
    }
}
