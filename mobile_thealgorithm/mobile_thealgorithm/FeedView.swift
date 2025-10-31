import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel: FeedViewModel
    let isAuthenticated: Bool
    
    init(apiClient: APIClient, isAuthenticated: Bool) {
        _viewModel = StateObject(wrappedValue: FeedViewModel(apiClient: apiClient))
        self.isAuthenticated = isAuthenticated
    }

    var body: some View {
        ZStack(alignment: .bottom) {
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
                        
                        // Select All / Deselect All Control
                        if !viewModel.posts.isEmpty {
                            Section {
                                Button(action: { viewModel.toggleSelectAll() }) {
                                    HStack {
                                        Image(systemName: viewModel.selectedPostIds.count == viewModel.posts.count ? "checkmark.square.fill" : "square")
                                            .foregroundColor(.blue)
                                        Text(viewModel.selectedPostIds.count == viewModel.posts.count ? "Deselect All" : "Select All")
                                        Spacer()
                                        Text("\(viewModel.posts.count) posts")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                        }

                        ForEach(viewModel.posts) { post in
                            FeedPostCell(
                                post: post,
                                isSelected: viewModel.selectedPostIds.contains(post.id),
                                onToggleSelect: {
                                    viewModel.toggleSelection(for: post.id)
                                }
                            )
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
            
            // Bulk Actions Bar (appears when posts are selected)
            if !viewModel.selectedPostIds.isEmpty {
                BulkActionsBar(
                    selectedCount: viewModel.selectedPostIds.count,
                    isGenerating: viewModel.isBulkGenerating,
                    isLiking: viewModel.isBulkLiking,
                    onGenerateReplies: { viewModel.bulkGenerateReplies() },
                    onLikeSelected: { viewModel.bulkLikePosts() }
                )
                .transition(.move(edge: .bottom))
                .animation(.spring(), value: viewModel.selectedPostIds.count)
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
        .alert("Success", isPresented: $viewModel.showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let message = viewModel.successMessage {
                Text(message)
            }
        }
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let message = viewModel.bulkErrorMessage {
                Text(message)
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

// MARK: - Bulk Actions Bar

private struct BulkActionsBar: View {
    let selectedCount: Int
    let isGenerating: Bool
    let isLiking: Bool
    let onGenerateReplies: () -> Void
    let onLikeSelected: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.square.fill")
                        .foregroundColor(.blue)
                    Text("\(selectedCount) selected")
                        .font(.headline)
                }
                
                Spacer()
                
                Button(action: onGenerateReplies) {
                    HStack(spacing: 6) {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isGenerating ? "Generating..." : "Generate Replies")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(10)
                }
                .disabled(isGenerating)
                
                Button(action: onLikeSelected) {
                    HStack(spacing: 6) {
                        if isLiking {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "heart.fill")
                        }
                        Text(isLiking ? "Liking..." : "Like")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.pink)
                    .cornerRadius(10)
                }
                .disabled(isLiking)
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 5, y: -2)
        }
    }
}

private struct FeedPostCell: View {
    let post: FeedPost
    let isSelected: Bool
    let onToggleSelect: () -> Void

    private var formattedDate: String {
        guard let date = post.createdAt else { return "Unknown date" }
        return date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Selection Checkbox
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .buttonStyle(.plain)
            
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
                    HStack {
                        Text("Reply:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(status.capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(statusColor(for: status))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(statusColor(for: status).opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                if let url = post.url {
                    Link(destination: url) {
                        Label("Open in X", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.05) : Color.clear)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "posted", "sent":
            return .green
        case "generated", "queued":
            return .blue
        case "pending":
            return .orange
        case "failed":
            return .red
        default:
            return .gray
        }
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

