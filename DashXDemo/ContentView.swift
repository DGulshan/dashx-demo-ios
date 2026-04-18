import SwiftUI

struct ContentView: View {
    @StateObject private var state = DemoState()
    @State private var showLogs = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    configureSection
                    uidSection
                    identitySection
                    subscribeSection
                    unsubscribeSection
                    resetSection
                }
                .padding()
            }
            .navigationTitle("DashX Demo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLogs = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityLabel("Logs")
                }
            }
            .sheet(isPresented: $showLogs) {
                LogsView()
            }
        }
    }

    // MARK: - Sections

    private var configureSection: some View {
        ButtonBlock(
            title: "Configure DashX",
            enabled: true,
            error: state.configureError,
            action: state.doConfigure
        )
    }

    private var uidSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("User UID").font(.caption).foregroundColor(.secondary)
            TextField("User UID", text: $state.uid)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .disabled(!state.isConfigured)
        }
    }

    private var identitySection: some View {
        let enabled = state.isConfigured && !state.uid.isEmpty
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                actionButton(
                    title: "Set DashX Identity",
                    enabled: enabled,
                    success: state.isIdentitySet,
                    action: state.doSetIdentity
                )
                asyncActionButton(
                    title: "Identify Account",
                    enabled: enabled,
                    success: state.isIdentified
                ) {
                    await state.doIdentify()
                }
            }
            if let error = state.identitySetError {
                ErrorText(prefix: "setIdentity", message: error)
            }
            if let error = state.identifyError {
                ErrorText(prefix: "identify", message: error)
            }
        }
    }

    private var subscribeSection: some View {
        let enabled = state.isIdentitySet && state.isIdentified && !state.isSubscribed
        return VStack(alignment: .leading, spacing: 6) {
            asyncActionButton(
                title: "Subscribe to Notifications",
                enabled: enabled,
                success: state.isSubscribed
            ) {
                await state.doSubscribe()
            }
            if let error = state.subscribeError {
                ErrorText(prefix: "subscribe", message: error)
            }
        }
    }

    private var unsubscribeSection: some View {
        let enabled = state.isSubscribed
        return VStack(alignment: .leading, spacing: 6) {
            asyncActionButton(
                title: "Unsubscribe",
                enabled: enabled,
                success: false
            ) {
                await state.doUnsubscribe()
            }
            if let error = state.unsubscribeError {
                ErrorText(prefix: "unsubscribe", message: error)
            }
        }
    }

    private var resetSection: some View {
        Button(role: .destructive) {
            state.doReset()
        } label: {
            Text("Reset")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .padding(.top, 8)
    }

    // MARK: - Button builders

    private func actionButton(
        title: String,
        enabled: Bool,
        success: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                if success { Image(systemName: "checkmark.circle.fill") }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!enabled)
    }

    private func asyncActionButton(
        title: String,
        enabled: Bool,
        success: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                Text(title)
                if success { Image(systemName: "checkmark.circle.fill") }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!enabled)
    }
}

// MARK: - Reusable pieces

private struct ButtonBlock: View {
    let title: String
    let enabled: Bool
    let error: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: action) {
                Text(title)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!enabled)

            if let error {
                ErrorText(prefix: "error", message: error)
            }
        }
    }
}

private struct ErrorText: View {
    let prefix: String
    let message: String

    var body: some View {
        Text("↳ \(prefix): \(message)")
            .font(.caption)
            .foregroundColor(.red)
    }
}

#Preview {
    ContentView()
}
