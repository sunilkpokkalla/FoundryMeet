import Foundation
import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var fcmToken: String?

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        refreshAuthorizationStatus()
    }

    func requestPermissionAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            refreshAuthorizationStatus()
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
                Messaging.messaging().isAutoInitEnabled = true
            }
        } catch {
            refreshAuthorizationStatus()
        }
    }

    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func persistTokenIfNeeded(_ token: String) async {
        fcmToken = token
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await Firestore.firestore().collection("users").document(uid).setData([
                "fcmTokens": FieldValue.arrayUnion([token]),
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
        } catch {
            // Non-fatal — token will retry on next launch.
        }
    }

    func scheduleChatReminder(chatId: String, title: String, startsAt: Date) {
        cancelChatReminder(chatId: chatId)

        let content = UNMutableNotificationContent()
        content.title = "Coffee chat soon"
        content.body = title
        content.sound = .default

        let fireDate = startsAt.addingTimeInterval(-15 * 60)
        guard fireDate > Date() else { return }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier(chatId: chatId),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelChatReminder(chatId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.reminderIdentifier(chatId: chatId)]
        )
    }

    private static func reminderIdentifier(chatId: String) -> String {
        "chat-reminder-\(chatId)"
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

extension PushNotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in
            await self.persistTokenIfNeeded(fcmToken)
        }
    }
}
