import Foundation

public struct Session: Equatable {
    public let id: String
    public let startTimestamp: Date

    public static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs.id == rhs.id && lhs.startTimestamp == rhs.startTimestamp
    }
}
