import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("Error requesting notification permission: \(error)")
            }
        }
    }

    func scheduleVaccineReminder(petName: String, vaccineName: String, date: Date) {
        // Reminder 3 days before
        let reminderDate = Calendar.current.date(byAdding: .day, value: -3, to: date) ?? date
        guard reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Vacuna pendiente 💉"
        content.body = "\(petName) necesita la vacuna \(vaccineName) en 3 días"
        content.sound = .default
        content.categoryIdentifier = "VACCINE_REMINDER"

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "vaccine_\(petName)_\(vaccineName)_\(date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)

        // Also schedule for the day of
        scheduleDayOfReminder(
            petName: petName,
            itemName: vaccineName,
            date: date,
            type: "vaccine",
            title: "Vacuna HOY 💉",
            body: "\(petName) tiene programada la vacuna \(vaccineName) para hoy"
        )
    }

    func scheduleAntiparasiticReminder(petName: String, productName: String, date: Date) {
        let reminderDate = Calendar.current.date(byAdding: .day, value: -3, to: date) ?? date
        guard reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Antiparasitario pendiente 💊"
        content.body = "\(petName) necesita \(productName) en 3 días"
        content.sound = .default
        content.categoryIdentifier = "ANTIPARASITIC_REMINDER"

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "antiparasitic_\(petName)_\(productName)_\(date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)

        scheduleDayOfReminder(
            petName: petName,
            itemName: productName,
            date: date,
            type: "antiparasitic",
            title: "Antiparasitario HOY 💊",
            body: "\(petName) tiene programado \(productName) para hoy"
        )
    }

    private func scheduleDayOfReminder(petName: String, itemName: String, date: Date, type: String, title: String, body: String) {
        guard date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "\(type)_day_\(petName)_\(itemName)_\(date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
