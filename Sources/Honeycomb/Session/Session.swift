import Foundation

internal protocol Session {
    var id: String { get }
    var startTimestamp: Date { get }

    init(id: String, startTimestamp: Date)
}

// TODO: Override equals so that we can s1 == s2 ?
internal func compareSesh(s1: any Session, s2: any Session) -> Bool {
    return s1.id == s2.id && s1.startTimestamp == s2.startTimestamp
}

internal class DefaultSession: Session {
    let id: String
    let startTimestamp: Date

    static var none: any Session = DefaultSession(id: "", startTimestamp: Date.distantPast)

    required public init(id: String, startTimestamp: Date) {
        self.id = id
        self.startTimestamp = startTimestamp
    }
}

