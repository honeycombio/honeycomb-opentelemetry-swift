import Foundation

public struct HoneycombSession: Equatable {
    public let id: String
    public let startTimestamp: Date

    public static func == (lhs: HoneycombSession, rhs: HoneycombSession) -> Bool {
        return lhs.id == rhs.id && lhs.startTimestamp == rhs.startTimestamp
    }
}
