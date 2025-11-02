import SwiftUI

struct ReplyQueueView: View {
    @StateObject private var viewModel: ReplyQueueViewModel
    let isAuthenticated: Bool
    
    init(apiClient: APIClient, isAuthenticated: Bool) {
        _viewModel = StateObject(wrappedValue: ReplyQueueViewModel(apiClient: apiClient))
        self.isAuthenticated = isAuthenticated
        print("🎯 [ReplyQueue] View initialized (isAuthenticated: \(isAuthenticated))")
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.replies.isEmpty {
                ProgressView("Loading queue…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = viewModel.errorMessage, viewModel.replies.isEmpty {
                ContentUnavailableView(
                    "No Replies",
                    systemImage: "bubble.right",
                    description: Text(message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.replies.isEmpty {
                ContentUnavailableView(
                    "No Replies in Queue",
                    systemImage: "tray",
                    description: Text("Generate replies from your feed to see them here")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        HStack {
                            Label("Queued Replies", systemImage: "clock")
                            Spacer()
                            Text("\(viewModel.queuedCount)")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Label("Total Replies", systemImage: "bubble.right")
                            Spacer()
                            Text("\(viewModel.totalCount)")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Summary")
                    }
                    
                    Section {
                        ForEach(viewModel.replies) { reply in
                            ReplyCell(reply: reply)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        viewModel.deleteReply(reply)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    if reply.status.lowercased() == "queued" {
                                        Button {
                                            viewModel.sendReplyNow(reply)
                                        } label: {
                                            Label("Send Now", systemImage: "paperplane.fill")
                                        }
                                        .tint(.blue)
                                    }
                                    
                                    if reply.status.lowercased() == "queued" || reply.status.lowercased() == "generated" {
                                        Button {
                                            viewModel.scheduleReply(reply)
                                        } label: {
                                            Label("Schedule", systemImage: "calendar")
                                        }
                                        .tint(.orange)
                                    }
                                }
                        }
                    } header: {
                        Text("Replies")
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { viewModel.refresh() }
            }
        }
        .navigationTitle("Reply Queue")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Menu {
                        Button(action: { viewModel.changeStatus(to: "generated") }) {
                            if viewModel.selectedStatus == "generated" {
                                Label("Generated", systemImage: "checkmark")
                            } else {
                                Text("Generated")
                            }
                        }
                        Button(action: { viewModel.changeStatus(to: "queued") }) {
                            if viewModel.selectedStatus == "queued" {
                                Label("Queued", systemImage: "checkmark")
                            } else {
                                Text("Queued")
                            }
                        }
                        Button(action: { viewModel.changeStatus(to: "scheduled") }) {
                            if viewModel.selectedStatus == "scheduled" {
                                Label("Scheduled", systemImage: "checkmark")
                            } else {
                                Text("Scheduled")
                            }
                        }
                        Button(action: { viewModel.changeStatus(to: "posted") }) {
                            if viewModel.selectedStatus == "posted" {
                                Label("Posted", systemImage: "checkmark")
                            } else {
                                Text("Posted")
                            }
                        }
                        Button(action: { viewModel.changeStatus(to: "failed") }) {
                            if viewModel.selectedStatus == "failed" {
                                Label("Failed", systemImage: "checkmark")
                            } else {
                                Text("Failed")
                            }
                        }
                        Divider()
                        Button(action: { viewModel.changeStatus(to: "all") }) {
                            if viewModel.selectedStatus == "all" {
                                Label("All", systemImage: "checkmark")
                            } else {
                                Text("All")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
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
        print("🎯 [ReplyQueue] loadOnceIfNeeded() called (isAuthenticated: \(isAuthenticated), repliesCount: \(viewModel.replies.count))")
        guard isAuthenticated else {
            print("🎯 [ReplyQueue] Not authenticated, skipping load")
            return
        }
        if viewModel.replies.isEmpty {
            print("🎯 [ReplyQueue] Replies are empty, calling viewModel.load()")
            viewModel.load()
        } else {
            print("🎯 [ReplyQueue] Replies already loaded (\(viewModel.replies.count)), skipping load")
        }
    }
}

private struct ReplyCell: View {
    let reply: DraftReply
    
    private var statusColor: Color {
        switch reply.status.lowercased() {
        case "posted": return .green
        case "failed": return .red
        case "generated", "queued": return .blue
        default: return .secondary
        }
    }
    
    private var statusIcon: String {
        switch reply.status.lowercased() {
        case "posted": return "checkmark.circle.fill"
        case "failed": return "xmark.circle.fill"
        case "generated", "queued": return "clock.fill"
        default: return "circle"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status Badge
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text(reply.status.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                
                Spacer()
                
                if let generatedAt = reply.generatedAt {
                    Text(generatedAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Original Post Context
            if let originalPost = reply.originalPost {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Replying to @\(originalPost.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(originalPost.text)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Generated Reply
            VStack(alignment: .leading, spacing: 6) {
                Text("Your Reply:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(reply.text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Metadata
            HStack(spacing: 16) {
                if let llmProvider = reply.llmProvider {
                    Label(llmProvider.capitalized, systemImage: "cpu")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let qualityScore = reply.qualityScore {
                    Label("\(Int(qualityScore * 100))%", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(qualityScoreColor(qualityScore))
                }
                
                if reply.status.lowercased() == "failed", let failureReason = reply.failureReason {
                    Label(failureReason, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func qualityScoreColor(_ score: Double) -> Color {
        switch score {
        case 0.8...: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

struct ReplyQueueView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ReplyQueueView(apiClient: APIClient(), isAuthenticated: true)
        }
    }
}

