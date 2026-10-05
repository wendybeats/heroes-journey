import Foundation
import UserNotifications

/// Local notification for a quest return (doc 24). Permission is asked at the first departure,
/// after the user has already chosen to send the character, never at launch (doc 22 pushback).
enum QuestNotifications {
    static let identifier = "quest.return"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(returnAt date: Date, characterName: String, line: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = "\(characterName) is back"
        content.body = line
        content.sound = .default
        let seconds = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    /// True once the user has answered the system prompt either way (owner QA 2026-10-05: ask once).
    static func isDecided() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus != .notDetermined
    }
    static func isAuthorized() async -> Bool {
        let s = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return s == .authorized || s == .provisional || s == .ephemeral
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
