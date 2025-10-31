import SwiftUI

struct MonitoredUsersView: View {
    @StateObject private var viewModel: MonitoredUsersViewModel
    let isAuthenticated: Bool
    
    init(apiClient: APIClient, isAuthenticated: Bool) {
        _viewModel = StateObject(wrappedValue: MonitoredUsersViewModel(apiClient: apiClient))
        self.isAuthenticated = isAuthenticated
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.users.isEmpty {
                ProgressView("Loading monitored users…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = viewModel.errorMessage, viewModel.users.isEmpty {
                ContentUnavailableView(
                    "No Monitored Users",
                    systemImage: "person.3",
                    description: Text(message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.users) { user in
                        MonitoredUserCell(user: user)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { viewModel.refresh() }
            }
        }
        .navigationTitle("User Management")
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
        if viewModel.users.isEmpty {
            viewModel.load()
        }
    }
}

private struct MonitoredUserCell: View {
    let user: MonitoredUser

    private var lastPostString: String {
        guard let date = user.lastPostAt else { return "Unknown" }
        return date.formatted(.relative(presentation: .named))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("@" + user.username)
                    .font(.headline)
                Spacer()
                if !user.isActive {
                    Text("Inactive")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if let displayName = user.displayName, !displayName.isEmpty {
                Text(displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Label("\(user.postsMonitored) posts", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("Last: \(lastPostString)", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct MonitoredUsersView_Previews: PreviewProvider {
    static var previews: some View {
        MonitoredUsersView(apiClient: APIClient(), isAuthenticated: true)
    }
}


