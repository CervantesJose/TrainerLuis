import Foundation
import UserNotifications

/// Schedules the "set finished" alert so a running timer still lands when the app isn't
/// on screen.
///
/// The countdown itself is a wall-clock calculation and stays correct across backgrounding —
/// but nothing *fires* while the app is suspended, so switching apps mid-set would otherwise
/// be silent. Every schedule replaces the previous request for the same slot, and pausing,
/// finishing or leaving cancels it, so a stale alert can never fire for a set that already
/// ended.
enum SetTimerNotifier {
    /// Asks once, at the moment a timer is first started, rather than on launch — the
    /// permission prompt then arrives with obvious context.
    ///
    /// - Returns: whether alerts can be posted. A refusal is not an error: the in-app
    ///   haptic still fires, so the timer stays usable.
    static func canNotify() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    static func schedule(id: String, title: String, body: String, at date: Date) async {
        guard await canNotify() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // Only breaks through Focus with the time-sensitive entitlement; without it iOS
        // quietly treats this as `.active`, which is still the behaviour we want.
        content.interruptionLevel = .timeSensitive

        // A time-interval trigger rather than a calendar one: the countdown is already a
        // duration, and `UNTimeIntervalNotificationTrigger` rejects anything <= 0.
        let delay = date.timeIntervalSinceNow
        guard delay > 0 else { return }

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        )

        // Adding with an existing identifier replaces the pending request, so restarting a
        // set can't leave two alerts armed.
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel(id: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }
}
