import UserNotifications

enum ReminderManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func schedule(enabled: Bool, hour: Int, minute: Int, lang: AppLanguage) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard enabled else { return }

        let content = UNMutableNotificationContent()
        if lang.resolved == .chinese {
            content.title = "写日记啦"
            content.body = "记录今天的美好时刻吧～"
        } else {
            content.title = "Time to Write"
            content.body = "Capture today's moments~"
        }
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
        center.add(request)
    }
}
