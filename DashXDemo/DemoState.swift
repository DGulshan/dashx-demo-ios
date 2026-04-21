import DashX
import Foundation
import SwiftUI
import UserNotifications

/// Owns the app's button-driven state machine and every SDK call. Each handler
/// writes at least three log entries (pressed → calling → success/failure) and
/// updates the `@Published` flags that drive button enablement in `ContentView`.
@MainActor
final class DemoState: ObservableObject {
    @Published var uid: String = ""

    @Published var isIdentitySet: Bool = false
    @Published var isIdentified: Bool = false
    @Published var isSubscribed: Bool = false

    @Published var identitySetError: String?
    @Published var identifyError: String?
    @Published var subscribeError: String?
    @Published var unsubscribeError: String?

    // Note: `DashX.configure(...)` runs once from `AppDelegate.didFinishLaunching` —
    // the demo no longer exposes a "Configure" button. All the state below assumes
    // the SDK is configured by the time the UI mounts.

    // MARK: - Set Identity

    func doSetIdentity() {
        DemoLog.shared.log(.info, "Set Identity pressed (uid=\(uid))")
        identitySetError = nil

        // DashX.setIdentity is sync and non-throwing; there's no failure signal to
        // surface. We still log + flip the flag so the button stays consistent with
        // the other paths.
        DashX.setIdentity(uid: uid, token: nil)
        isIdentitySet = true
        DemoLog.shared.log(.info, "setIdentity → success")
    }

    // MARK: - Identify

    func doIdentify() async {
        DemoLog.shared.log(.info, "Identify Account pressed (uid=\(uid))")
        identifyError = nil

        do {
            DemoLog.shared.log(.info, "Calling DashX.identify(options: [\"uid\": \"\(uid)\"])")
            try await DashX.identify(options: ["uid": uid])
            isIdentified = true
            DemoLog.shared.log(.info, "identify → success")
        } catch {
            identifyError = error.localizedDescription
            DemoLog.shared.log(.error, "identify → \(error.localizedDescription)")
        }
    }

    // MARK: - Subscribe / Unsubscribe

    func doSubscribe() async {
        DemoLog.shared.log(.info, "Subscribe to Notifications pressed")
        subscribeError = nil

        // Fire the permission prompt (first time) + `registerForRemoteNotifications`
        // path inside the SDK. No-op if the user already granted.
        DashX.requestNotificationPermission { status in
            DemoLog.shared.log(.info, "Notification permission status: \(authStatusString(status))")
        }

        do {
            DemoLog.shared.log(.info, "Calling DashX.subscribe()")
            try await DashX.subscribe()
            isSubscribed = true
            DemoLog.shared.log(.info, "subscribe → success")
        } catch {
            subscribeError = error.localizedDescription
            DemoLog.shared.log(.error, "subscribe → \(error.localizedDescription)")
        }
    }

    func doUnsubscribe() async {
        DemoLog.shared.log(.info, "Unsubscribe pressed")
        unsubscribeError = nil

        do {
            DemoLog.shared.log(.info, "Calling DashX.unsubscribe()")
            try await DashX.unsubscribe()
            isSubscribed = false
            DemoLog.shared.log(.info, "unsubscribe → success")
        } catch {
            unsubscribeError = error.localizedDescription
            DemoLog.shared.log(.error, "unsubscribe → \(error.localizedDescription)")
        }
    }

    // MARK: - Reset

    func doReset() {
        DemoLog.shared.log(.info, "Reset pressed")

        DashX.reset()

        // Deliberately NOT clearing any `configured` flag — `DashX.reset()` only
        // clears identity + FCM state; the SDK stays configured with the keys
        // already loaded at `AppDelegate.didFinishLaunching` time.
        uid = ""
        isIdentitySet = false
        isIdentified = false
        isSubscribed = false

        identitySetError = nil
        identifyError = nil
        subscribeError = nil
        unsubscribeError = nil

        DemoLog.shared.log(.info, "reset → all local state cleared")
    }
}

private func authStatusString(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .denied: return "denied"
    case .authorized: return "authorized"
    case .provisional: return "provisional"
    case .ephemeral: return "ephemeral"
    @unknown default: return "unknown(\(status.rawValue))"
    }
}
