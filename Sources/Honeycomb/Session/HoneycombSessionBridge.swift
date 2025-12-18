import Foundation
import Sessions
import OpenTelemetryApi

// MARK: - Deprecated Notifications (maintained for backward compatibility)

extension Notification.Name {
    @available(*, deprecated, message: "Use SessionEventNotification from OpenTelemetry Sessions instead")
    public static let sessionStarted = Notification.Name("io.honeycomb.app.session.started")

    @available(*, deprecated, message: "Use SessionEventNotification from OpenTelemetry Sessions instead")
    public static let sessionEnded = Notification.Name("io.honeycomb.app.session.ended")
}

// MARK: - Session Bridge

extension HoneycombSession {
    /// Converts an OpenTelemetry Session to a HoneycombSession
    static func from(_ session: Session) -> HoneycombSession {
        return HoneycombSession(
            id: session.id,
            startTimestamp: session.startTime
        )
    }
}

/// Helper class to post both old and new notifications for backward compatibility
class SessionNotificationBridge {
    private var lastSessionId: String?

    init() {
        // Listen to OTel session events and repost as legacy notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name(SessionConstants.sessionEventNotification),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let session = notification.object as? Session else { return }
            self?.handleSessionChange(session)
        }
    }

    private func handleSessionChange(_ newSession: Session) {
        let isNewSession = lastSessionId != newSession.id

        if isNewSession {
            // Post sessionEnded for previous session if exists
            if lastSessionId != nil {
                NotificationCenter.default.post(
                    name: .sessionEnded,
                    object: nil,
                    userInfo: ["previousSession": HoneycombSession.from(newSession)]
                )
            }

            // Post sessionStarted for new session
            var userInfo: [String: Any] = ["session": HoneycombSession.from(newSession)]
            if let prevId = newSession.previousId {
                // Note: We don't have full previous session details, only ID
                userInfo["previousSessionId"] = prevId
            }
            NotificationCenter.default.post(
                name: .sessionStarted,
                object: nil,
                userInfo: userInfo
            )

            lastSessionId = newSession.id
        }
    }
}
