import Foundation
import SwiftUI

/// An append-only, bounded in-memory log used by both the SDK-call handlers and the
/// `LogsView` sheet. Every button handler writes three entries (pressed → calling →
/// result) so the user can trace each SDK call chronologically.
@MainActor
final class DemoLog: ObservableObject {
    static let shared = DemoLog()

    enum Level: String {
        case info
        case error
    }

    struct Entry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: Level
        let message: String
    }

    private static let maxEntries = 500

    @Published private(set) var entries: [Entry] = []

    private init() {}

    /// Append a log entry. Safe to call from any isolation context — hops to the main
    /// actor because `@Published` + SwiftUI must be mutated on main.
    nonisolated func log(_ level: Level, _ message: String) {
        Task { @MainActor in
            DemoLog.shared.append(level: level, message: message)
        }
    }

    private func append(level: Level, message: String) {
        let entry = Entry(timestamp: Date(), level: level, message: message)
        entries.append(entry)
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
