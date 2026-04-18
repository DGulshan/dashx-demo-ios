# DashXDemo — iOS push integration reference (DashX 1.3.0)

A minimal SwiftUI app that wires every push-notification surface of the [DashX iOS SDK](https://github.com/dashxhq/dashx-ios) 1.3.0:

- APNs token forwarding + FCM token handoff
- Alert-push rendering (iOS 18.5 safe — no silent-push throttling)
- Rich notifications: image attachments, action-button categories
- Delivered-tracking from a Notification Service Extension (works even when the app is killed)
- Deep-link and action-button tap handling through the DashX AppDelegate hooks

Use this as a copy-paste reference when adding DashX push to your own app.

## Prerequisites

- Xcode 15+
- iOS 17+ deployment target in your app (DashX itself supports iOS 13+; this demo chose 17 for modern SwiftUI APIs)
- A Firebase project with APNs key uploaded. `GoogleService-Info.plist` on hand.
- A DashX workspace with a Public Key and Base URI.

---

## Integration — step by step

Each step links to the file in this repo that shows the finished result.

### Step 1 — add the DashX SPM packages

In Xcode: **File → Add Package Dependencies…** and enter:

```
https://github.com/dashxhq/dashx-ios.git
```

Pin the version to **Exact Version `1.3.0`**. Add the three products to the targets that need them:

| Product | Target | Why |
|---|---|---|
| `DashX` | Main app | Core SDK (configure, identify, track, subscribe, …) |
| `DashXFirebase` | Main app | Ships `DashXAppDelegate` + Firebase Messaging glue |
| `DashXNotificationServiceExtension` | NSE target (see Step 7) | Base class for rich-push handling |

### Step 2 — add Firebase

DashX push uses FCM as the transport. Add the Firebase iOS SDK and drop your `GoogleService-Info.plist` into the main app target:

- SPM: `https://github.com/firebase/firebase-ios-sdk.git` → add `FirebaseMessaging` to the main app.
- `GoogleService-Info.plist`: drag into Xcode, check "Copy items if needed" and add to the main app target only.

The demo's copy lives at [`DashXDemo/GoogleService-Info.plist`](./DashXDemo/GoogleService-Info.plist).

### Step 3 — configure `Info.plist`

Add these keys to the main app's `Info.plist` (see [`DashXDemo/Info.plist`](./DashXDemo/Info.plist)):

```xml
<key>DASHX_PUBLIC_KEY</key>
<string>your-public-key</string>
<key>DASHX_BASE_URI</key>
<string>https://api.dashx.com/graphql</string>
<key>DASHX_TARGET_ENVIRONMENT</key>
<string>production</string>

<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>

<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

- The first three keys are read at runtime by `DashX.configure(...)` via the `Configuration` helper (Step 5).
- `remote-notification` background mode is required so iOS wakes the app to receive silent pushes (even though DashX 1.3.0 uses alert pushes primarily, some orchestration flows still use background wake-ups).
- `FirebaseAppDelegateProxyEnabled = false` disables Firebase's AppDelegate swizzling — `DashXAppDelegate` handles APNs forwarding explicitly (Step 5), and double-forwarding causes duplicate registrations.

### Step 4 — add the push entitlement

Create a `.entitlements` file for the main app with:

```xml
<key>aps-environment</key>
<string>development</string>
```

See [`DashXDemo/DashXDemo.entitlements`](./DashXDemo/DashXDemo.entitlements). Change `development` to `production` for release builds.

### Step 5 — AppDelegate: subclass `DashXAppDelegate`, wire Firebase + MessagingDelegate

Create an `AppDelegate` class that subclasses `DashXAppDelegate` (from `DashXFirebase`) and implements `MessagingDelegate`. This is where Firebase is booted and the FCM token is handed to DashX. See [`DashXDemo/AppDelegate.swift`](./DashXDemo/AppDelegate.swift).

```swift
import DashX
import DashXFirebase
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

class AppDelegate: DashXAppDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        DashXLog.setLogLevel(to: .debug) // turn off for release

        FirebaseApp.configure()
        Messaging.messaging().delegate = self

        // DashX.configure() can go here, or — as in this demo — get called later
        // from a user action if you want to gate initialization on consent.

        return true
    }

    // Show banners for pushes that arrive while the app is in foreground.
    // Default in DashXAppDelegate is `[]` which suppresses them silently.
    override func notificationDeliveredInForeground(
        message: [AnyHashable: Any]
    ) -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }

    // Optional: intercept tap navigation. Return `true` to handle yourself, `false`
    // (default) to let the SDK run its default routing (handleLink for deepLink,
    // in-app Safari for richLanding, etc.).
    override func onNotificationClicked(
        message: [AnyHashable: Any],
        action: NavigationAction?,
        actionIdentifier: String
    ) -> Bool {
        // Route to your own screens here, e.g. based on `action.screen(name:data:)`.
        false
    }

    // Optional: custom deep-link handling. `super.handleLink(url:)` opens the URL
    // via `UIApplication.shared.open(_:)` (Safari or universal-link handlers).
    override func handleLink(url: URL) {
        super.handleLink(url: url)
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        DashX.setFCMToken(to: fcmToken)
    }
}
```

### Step 6 — SwiftUI lifecycle adaptor

In your `@main` `App`, install the AppDelegate via `@UIApplicationDelegateAdaptor`. See [`DashXDemo/DashXDemoApp.swift`](./DashXDemo/DashXDemoApp.swift).

```swift
@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### Step 7 — add the Notification Service Extension target

Without an NSE, alert-pushes still display but you lose image attachments, dynamic action buttons, and delivered tracking when the app is killed. Add it.

1. **File → New → Target… → Notification Service Extension**. Name it something like `MyAppNotificationService`.
2. Delete the Xcode-generated `NotificationService.swift`.
3. In the new NSE target's *Frameworks and Libraries*, add **`DashXNotificationServiceExtension`** (from the same `dashx-ios` SPM package you added in Step 1).
4. Create a new `NotificationService.swift` in the NSE target (see [`DashXDemoNotificationService/NotificationService.swift`](./DashXDemoNotificationService/NotificationService.swift)):

    ```swift
    import DashXNotificationServiceExtension

    final class NotificationService: DashXNotificationServiceExtension {}
    ```

    That one-liner is the entire extension. The SDK base class:
    - Attaches the image at `dashx.image` to the banner before iOS displays it.
    - Computes a SHA-256 hash of the action-button set and registers a matching `UNNotificationCategory` so long-press reveals the buttons.
    - Sets `content.sound = .default` when the server didn't specify a sound.
    - Fires `trackMessage(status: DELIVERED)` via GraphQL (bounded by a 3-second semaphore wait so iOS actually delivers the HTTP request before killing the extension).

5. In the NSE target's `Info.plist`, add the same DASHX keys as the main app — the NSE runs in its own process and can't see the main app's bundle. See [`DashXDemoNotificationService/Info.plist`](./DashXDemoNotificationService/Info.plist):

    ```xml
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.usernotifications.service</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).NotificationService</string>
    </dict>
    <key>DASHX_BASE_URI</key>
    <string>https://api.dashx.com/graphql</string>
    <key>DASHX_PUBLIC_KEY</key>
    <string>your-public-key</string>
    <key>DASHX_TARGET_ENVIRONMENT</key>
    <string>production</string>
    ```

6. The main app's **Build Phases → Embed Foundation Extensions** phase should automatically list the new `.appex`. If not, add it manually. Confirm the built app bundle has `PlugIns/MyAppNotificationService.appex` inside.

### Step 8 — the DashX lifecycle calls

Call these from your own UI / app logic. This demo routes each through a dedicated button so you can see each step independently; in production you'd typically call `configure` at launch, `setIdentity` + `identify` after login, and `subscribe` when the user grants push permission.

```swift
import DashX

// Once, early in the app lifecycle.
DashX.configure(
    withPublicKey: try Configuration.value(for: "DASHX_PUBLIC_KEY"),
    baseURI:        try? Configuration.value(for: "DASHX_BASE_URI"),
    targetEnvironment: try? Configuration.value(for: "DASHX_TARGET_ENVIRONMENT")
)

// After the user logs in.
DashX.setIdentity(uid: userId, token: nil)
try await DashX.identify(options: ["uid": userId])

// When the user grants push permission.
DashX.requestNotificationPermission { status in
    // .authorized / .denied / .notDetermined / .provisional / .ephemeral
}
try await DashX.subscribe()

// On logout / user-triggered opt-out.
try await DashX.unsubscribe()
DashX.reset()
```

The `Configuration.value(for:)` helper is a tiny generic Info.plist reader — see [`DashXDemo/Configuration.swift`](./DashXDemo/Configuration.swift). Copy it into your app verbatim, or replace with your own source of build-time secrets.

---

## Running this demo locally

```bash
cd dashx-demo-ios
open DashXDemo.xcodeproj
```

Pick an **iPhone 17 Simulator** (or any iOS 17+ destination), ⌘R. Xcode resolves the `dashx-ios` 1.3.0 package + transitive Firebase/Apollo deps on first open.

Walk through the on-screen buttons in order:

1. **Configure DashX** — reads the three DASHX keys from `Info.plist` and calls `DashX.configure(...)`.
2. **User UID** input — enabled after Configure.
3. **Set DashX Identity** → **Identify Account** — unlocks Subscribe.
4. **Subscribe to Notifications** — permission prompt + `DashX.subscribe()`. FCM token gets forwarded into the SDK by `messaging(_:didReceiveRegistrationToken:)`.
5. Send a test broadcast from the DashX dashboard → banner appears (even in foreground, with sound), and tapping it fires `handleLink`.
6. **Unsubscribe** → **Reset** — returns to initial state.

Tap the 🔍 icon in the toolbar to open the Logs sheet. Every SDK call, permission response, FCM token event, and push tap gets an entry there.

---

## Troubleshooting

- **Build fails to resolve `dashx-ios`** — ensure the package URL is correct and you pinned *exact* version `1.3.0`. If Xcode is caching an older resolution, *File → Packages → Reset Package Caches*.
- **Subscribe succeeds but no push arrives** — open Logs and look for `FCM token received (len=...)`. If that entry is missing, Firebase never got a token (most commonly on iOS Simulator — push requires a real device).
- **Foreground banner doesn't play a sound** — make sure you overrode `notificationDeliveredInForeground` to return `[.banner, .list, .sound, .badge]` (Step 5). Default is `[]`.
- **Images on banner missing on real device** — check that the NSE target was embedded. Run `ls <app.app>/PlugIns/` on the installed bundle; you should see `*NotificationService.appex`. Also confirm `aps.mutable-content: 1` is in the inbound payload (DashX backend sets this automatically for 1.3.0+ contacts).
- **Action buttons don't appear** — the NSE must succeed at registering the category before iOS renders the banner. If you see the banner but no buttons, it's the 2-second semaphore timeout inside the NSE — check Console.app filtered to your NSE process.

---

## File layout of this demo

```
DashXDemo/
├── DashXDemoApp.swift            SwiftUI @main + @UIApplicationDelegateAdaptor
├── AppDelegate.swift             DashXAppDelegate subclass + MessagingDelegate
├── ContentView.swift             button stack + inline errors
├── DemoState.swift               @MainActor ObservableObject owning every SDK call
├── Logger.swift                  in-memory log store (bounded, @Published)
├── LogsView.swift                scrollable log viewer with Clear
├── Configuration.swift           typed Info.plist reader (copied verbatim from the
│                                 existing dashx-demo-ios)
├── Info.plist                    DASHX_* keys + UIBackgroundModes + Firebase proxy
├── DashXDemo.entitlements        aps-environment = development
└── GoogleService-Info.plist      Firebase project config

DashXDemoNotificationService/
├── NotificationService.swift     final class NotificationService: DashXNotificationServiceExtension {}
└── Info.plist                    NSExtension manifest + DASHX_* keys
```

## Caveats

- **Bundle-ID clash**: `com.dashxdemo.app` is shared with the more feature-rich `dashxhq/dashx-demo-ios` app, so both can't be installed side-by-side on the same device/simulator.
- **Simulator push**: use `xcrun simctl push <device> com.dashxdemo.app <payload.apns>` or drag an `.apns` file onto the simulator window. Real FCM round-trips require a physical device with push entitlements provisioned.
- **Not production-hardened**: this app intentionally skips auth, error recovery strategies, background fetch, scene multi-window support, etc. Use it as a reference, not a template.
