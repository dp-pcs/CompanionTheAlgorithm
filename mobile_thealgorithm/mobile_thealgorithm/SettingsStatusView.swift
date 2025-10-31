import SwiftUI

struct SettingsStatusView: View {
    @StateObject private var viewModel: SettingsStatusViewModel
    let isAuthenticated: Bool
    
    init(apiClient: APIClient, isAuthenticated: Bool) {
        _viewModel = StateObject(wrappedValue: SettingsStatusViewModel(apiClient: apiClient))
        self.isAuthenticated = isAuthenticated
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.status == nil {
                ProgressView("Loading settings…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = viewModel.errorMessage, viewModel.status == nil {
                ContentUnavailableView(
                    "Unable to Load",
                    systemImage: "gear",
                    description: Text(message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let status = viewModel.status {
                Form {
                    Section("LLM Providers") {
                        SettingsRow(title: "OpenAI", isEnabled: status.llmProviders.openai)
                        SettingsRow(title: "Anthropic", isEnabled: status.llmProviders.anthropic)
                        SettingsRow(title: "Google", isEnabled: status.llmProviders.google)
                    }

                    Section("OAuth Connections") {
                        SettingsRow(title: "X.com Connected", isEnabled: status.oauth.xConnected)
                        SettingsRow(title: "Google Connected", isEnabled: status.oauth.googleConnected)
                    }

                    Section("Account") {
                        SettingsRow(title: "Administrator", isEnabled: status.currentUser.isAdmin)
                    }

                    Section("System") {
                        SettingsRow(title: "X API Available", isEnabled: status.system.xAPIAvailable)
                    }
                }
                .refreshable { viewModel.refresh() }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button(action: { viewModel.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await loadOnceIfNeeded() }
        .onChange(of: isAuthenticated) { newValue in
            guard newValue else { return }
            viewModel.refresh()
        }
    }

    @Sendable
    private func loadOnceIfNeeded() async {
        guard isAuthenticated else { return }
        if viewModel.status == nil {
            viewModel.load()
        }
    }
}

private struct SettingsRow: View {
    let title: String
    let isEnabled: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(isEnabled ? .green : .red)
        }
    }
}

struct SettingsStatusView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsStatusView(apiClient: APIClient(), isAuthenticated: true)
    }
}


