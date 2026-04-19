import DashXNotificationServiceExtension

/// Subclasses `DashXNotificationService` to opt into DashX 1.3.0+ rich-push
/// handling before iOS displays the banner:
///
/// - Image attachments: downloaded from `dashx.image` and attached to the notification.
/// - Dynamic action buttons: a `UNNotificationCategory` is registered with actions
///   from `dashx.action_buttons`, matching the hash the backend stamps into
///   `aps.category`.
/// - Delivered tracking: a `trackNotification(event: "delivered")` GraphQL mutation
///   fires even when the host app isn't running, provided this target's Info.plist
///   carries the same `DASHX_BASE_URI` / `DASHX_PUBLIC_KEY` keys the main app uses.
final class NotificationService: DashXNotificationService {}
