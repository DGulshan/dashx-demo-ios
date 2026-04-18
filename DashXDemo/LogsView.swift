import SwiftUI

struct LogsView: View {
    @ObservedObject private var log = DemoLog.shared
    @Environment(\.dismiss) private var dismiss

    private static let timestampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        return df
    }()

    var body: some View {
        NavigationStack {
            Group {
                if log.entries.isEmpty {
                    ContentUnavailableView(
                        "No logs yet",
                        systemImage: "doc.text",
                        description: Text("Tap any button on the home screen to start seeing events.")
                    )
                } else {
                    ScrollViewReader { proxy in
                        List(log.entries) { entry in
                            entryRow(entry)
                                .id(entry.id)
                        }
                        .listStyle(.plain)
                        .onAppear {
                            scrollToLatest(proxy: proxy)
                        }
                        .onChange(of: log.entries.count) { _, _ in
                            scrollToLatest(proxy: proxy)
                        }
                    }
                }
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        log.clear()
                    } label: {
                        Text("Clear")
                    }
                    .disabled(log.entries.isEmpty)
                }
            }
        }
    }

    private func entryRow(_ entry: DemoLog.Entry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(Self.timestampFormatter.string(from: entry.timestamp))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            Text(entry.level.rawValue.uppercased())
                .font(.caption.bold())
                .foregroundColor(entry.level == .error ? .red : .blue)
                .frame(width: 48, alignment: .leading)
            Text(entry.message)
                .font(.caption)
                .foregroundColor(entry.level == .error ? .red : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func scrollToLatest(proxy: ScrollViewProxy) {
        guard let last = log.entries.last else { return }
        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
    }
}

#Preview {
    LogsView()
}
