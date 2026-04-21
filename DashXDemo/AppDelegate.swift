import DashX
import DashXFirebase
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

/// Subclass of `DashXAppDelegate` to get DashX's notification delivery/click/dismiss
/// tracking for free. Adds Firebase + MessagingDelegate wiring so the FCM token can
/// be forwarded into the DashX client when it arrives, and configures DashX at
/// launch so the SDK is usable from the moment the UI comes up.
class AppDelegate: DashXAppDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Chatty logs for the demo so the Xcode console mirrors the in-app Logs sheet.
        DashXLog.setLogLevel(to: .debug)

        FirebaseApp.configure()
        Messaging.messaging().delegate = self

        DemoLog.shared.log(.info, "AppDelegate.didFinishLaunching — Firebase configured")

        Self.configureDashX()

        return true
    }

    /// Reads `DASHX_*` Info.plist keys via the `Configuration` helper and calls
    /// `DashX.configure` on main. Done in `didFinishLaunching` rather than from
    /// a button tap because that's the production-shaped integration — you
    /// want the SDK ready for `userNotificationCenter(_:didReceive:)` callbacks
    /// on cold-launch notification taps.
    private static func configureDashX() {
        do {
            let publicKey: String = try Configuration.value(for: "DASHX_PUBLIC_KEY")
            let baseURI: String? = try? Configuration.value(for: "DASHX_BASE_URI")
            let targetEnv: String? = try? Configuration.value(for: "DASHX_TARGET_ENVIRONMENT")

            DashX.configure(
                withPublicKey: publicKey,
                baseURI: baseURI,
                targetEnvironment: targetEnv
            )
            DemoLog.shared.log(.info, "DashX.configure() called from didFinishLaunching")
        } catch {
            DemoLog.shared.log(.error, "DashX.configure failed — \(error)")
        }
    }

    // MARK: - Foreground notification presentation
    //
    // `DashXAppDelegate.notificationDeliveredInForeground` defaults to `[]`, which
    // tells iOS to silently drop notifications that arrive while the app is in the
    // foreground — you'd only see them after backgrounding. Override to show them
    // in-app too. `.banner`/`.list`/`.sound`/`.badge` is the standard iOS 14+ set.

    override func notificationDeliveredInForeground(
        message: [AnyHashable: Any]
    ) -> UNNotificationPresentationOptions {
        DemoLog.shared.log(.info, "Notification delivered while app in foreground")
        return [.banner, .list, .sound, .badge]
    }

    // MARK: - Notification tap / deep link hooks
    //
    // Returning `false` from `onNotificationClicked` tells DashX to apply its default
    // handling for the resolved `NavigationAction`: deep-link URLs flow through
    // `handleLink`, rich landings open in an in-app Safari view, etc. The demo
    // just logs each step so the Logs sheet shows the full tap flow. Return `true`
    // here if you want to intercept and navigate yourself (e.g. push a screen).

    override func onNotificationClicked(
        message: [AnyHashable: Any],
        action: NavigationAction?,
        actionIdentifier: String
    ) -> Bool {
        switch action {
        case .deepLink(let url):
            DemoLog.shared.log(.info, "Notification click → deepLink: \(url.absoluteString) (actionIdentifier=\(actionIdentifier))")
        case .richLanding(let url):
            DemoLog.shared.log(.info, "Notification click → richLanding: \(url.absoluteString)")
        case .screen(let name, let data):
            DemoLog.shared.log(.info, "Notification click → screen: \(name) data=\(data ?? [:])")
        case .clickAction(let act):
            DemoLog.shared.log(.info, "Notification click → clickAction: \(act)")
        case .none:
            DemoLog.shared.log(.info, "Notification click → no NavigationAction (actionIdentifier=\(actionIdentifier))")
        }
        return false // let DashX apply its default behaviour
    }

    override func handleLink(url: URL) {
        DemoLog.shared.log(.info, "handleLink invoked: \(url.absoluteString) — forwarding to system")
        // Log, then let the SDK default run (`UIApplication.shared.open(url)` —
        // Safari for http/https, routed via scene delegate for custom schemes).
        super.handleLink(url: url)
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else {
            DemoLog.shared.log(.info, "FCM registration token arrived but was nil")
            return
        }
        DemoLog.shared.log(.info, "FCM token received (len=\(fcmToken.count)). Forwarding to DashX.")
        DashX.setFCMToken(to: fcmToken)
    }
}
