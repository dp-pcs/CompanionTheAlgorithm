import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel: FeedViewModel
    let isAuthenticated: Bool
    
    init(apiClient: APIClient, isAuthenticated: Bool) {
        _viewModel = StateObject(wrappedValue: FeedViewModel(apiClient: apiClient))
        self.isAuthenticated = isAuthenticated
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView("Loading feed…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = viewModel.errorMessage, viewModel.posts.isEmpty {
                ContentUnavailableView(
                    "Unable to Load Feed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = viewModel.infoMessage, viewModel.posts.isEmpty {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No Recent Posts",
                        systemImage: "text.bubble",
                        description: Text(message)
                    )

                    Button(action: { viewModel.fetchTimeline() }) {
                        Label("Fetch Timeline", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isAuthenticated)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if let summary = viewModel.lastFetchSummary {
                        Section("Last Fetch") {
                            Text(summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    ForEach(viewModel.posts) { post in
                        FeedPostCell(post: post)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await MainActor.run {
                        if isAuthenticated {
                            viewModel.refresh()
                        }
                    }
                }
            }
        }
        .navigationTitle("Feed")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if viewModel.isLoading || viewModel.isRefreshing {
                    ProgressView()
                } else {
                    Button(action: { viewModel.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!isAuthenticated)
                    .accessibilityLabel("Refresh feed")

                    Button(action: { viewModel.fetchTimeline() }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!isAuthenticated)
                    .accessibilityLabel("Fetch timeline from X")
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
        if viewModel.posts.isEmpty {
            viewModel.load()
        }
    }
}

private struct FeedPostCell: View {
    let post: FeedPost

    private var formattedDate: String {
        guard let date = post.createdAt else { return "Unknown date" }
        return date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                if let url = post.authorProfileImage {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(post.authorName ?? "@" + post.authorUsername)
                            .font(.headline)
                        if post.authorVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                        Spacer()
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("@" + post.authorUsername)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(post.text)
                .font(.body)
                .foregroundColor(.primary)

            if let list = post.listSource, !list.isEmpty {
                Text("List: \(list)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            let engagement = post.engagement
            if engagement.likes + engagement.retweets + engagement.replies > 0 {
                HStack(spacing: 16) {
                    Label("\(engagement.likes)", systemImage: "heart.fill")
                        .foregroundColor(.pink)
                    Label("\(engagement.retweets)", systemImage: "arrow.2.squarepath")
                        .foregroundColor(.green)
                    Label("\(engagement.replies)", systemImage: "bubble.right")
                        .foregroundColor(.blue)
                }
                .font(.caption)
            }

            if let status = post.replyStatus.lowercased().nilIfEmpty(), status != "none" {
                Text("Reply status: \(status.capitalized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let url = post.url {
                Link(destination: url) {
                    Label("Open in X", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private extension String {
    func nilIfEmpty() -> String? {
        isEmpty ? nil : self
    }
}

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView(apiClient: APIClient(), isAuthenticated: true)
    }
}

