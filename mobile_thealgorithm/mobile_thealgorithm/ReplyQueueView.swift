import SwiftUI

struct ReplyQueueView: View {
    @StateObject private var viewModel: ReplyQueueViewModel
    let isAuthenticated: Bool
    
    @State private var isSelecting = false
    @State private var selectedReplyIds: Set<String> = []
    @AppStorage("hasSeenSwipeHint") private var hasSeenSwipeHint = false
    @State private var showSwipeHint = false
    
    init(apiClient: APIClient, isAuthenticated: Bool) {
        _viewModel = StateObject(wrappedValue: ReplyQueueViewModel(apiClient: apiClient))
        self.isAuthenticated = isAuthenticated
        print("🎯 [ReplyQueue] View initialized (isAuthenticated: \(isAuthenticated))")
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.replies.isEmpty {
                loadingView
            } else if let message = viewModel.errorMessage, viewModel.replies.isEmpty {
                errorView(message: message)
            } else if viewModel.replies.isEmpty {
                emptyView
            } else {
                queueListView
            }
        }
        .navigationTitle("Reply Queue")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !viewModel.replies.isEmpty {
                    Button(isSelecting ? "Done" : "Select") {
                        isSelecting.toggle()
                        if !isSelecting {
                            selectedReplyIds.removeAll()
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    statusFilterMenu
                }
            }
        }
        .task { await loadOnceIfNeeded() }
        .onChange(of: isAuthenticated) { newValue in
            guard newValue else { return }
            viewModel.refresh()
        }
        .onChange(of: viewModel.replies) { replies in
            // Show hint when replies first load
            if !replies.isEmpty && !hasSeenSwipeHint && !showSwipeHint {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showSwipeHint = true
                }
            }
        }
        .alert("Success", isPresented: $viewModel.showSuccessMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.successMessage)
        }
    }
    
    private var queueListView: some View {
        List {
                    // Swipe Hint Banner
                    if showSwipeHint && !hasSeenSwipeHint {
                        Section {
                            HStack(spacing: 12) {
                                Image(systemName: "hand.draw")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("💡 Quick Actions")
                                        .font(.headline)
                                    Text("Swipe left to Send or Schedule • Swipe right to Delete")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Or tap 'Select' to manage multiple replies at once")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showSwipeHint = false
                                    hasSeenSwipeHint = true
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.blue.opacity(0.1))
                    }
                    
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
                            HStack(spacing: 12) {
                                if isSelecting {
                                    Button(action: { toggleSelection(reply.id) }) {
                                        Image(systemName: selectedReplyIds.contains(reply.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedReplyIds.contains(reply.id) ? .blue : .gray)
                                            .font(.title3)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                ReplyCell(reply: reply)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isSelecting {
                                    toggleSelection(reply.id)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !isSelecting {
                                    Button(role: .destructive) {
                                        viewModel.deleteReply(reply)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if !isSelecting {
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
                        }
                    } header: {
                        Text("Replies")
                    }
                    
                    // Batch Actions Section (only show when selecting)
                    if isSelecting && !selectedReplyIds.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Button(action: sendSelectedNow) {
                                    HStack {
                                        Image(systemName: "paperplane.fill")
                                        Text("Send \(selectedReplyIds.count) Selected Now")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: scheduleSelected) {
                                    HStack {
                                        Image(systemName: "calendar")
                                        Text("Schedule \(selectedReplyIds.count) Selected")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                
                                Button(role: .destructive, action: deleteSelected) {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Delete \(selectedReplyIds.count) Selected")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.15))
                                    .foregroundColor(.red)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                            .listRowInsets(EdgeInsets())
                            .padding(.top, 8)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { viewModel.refresh() }
    }
    
    private var statusFilterMenu: some View {
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
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        ProgressView("Loading queue…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(message: String) -> some View {
        ContentUnavailableView(
            "No Replies",
            systemImage: "bubble.right",
            description: Text(message)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        ContentUnavailableView(
            "No Replies in Queue",
            systemImage: "tray",
            description: Text("Generate replies from your feed to see them here")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    // MARK: - Multi-Select Actions
    
    private func toggleSelection(_ replyId: String) {
        if selectedReplyIds.contains(replyId) {
            selectedReplyIds.remove(replyId)
        } else {
            selectedReplyIds.insert(replyId)
        }
    }
    
    private func sendSelectedNow() {
        let replies = viewModel.replies.filter { selectedReplyIds.contains($0.id) }
        viewModel.sendRepliesBatch(replies)
        isSelecting = false
        selectedReplyIds.removeAll()
    }
    
    private func scheduleSelected() {
        let replies = viewModel.replies.filter { selectedReplyIds.contains($0.id) }
        viewModel.scheduleRepliesBatch(replies)
        isSelecting = false
        selectedReplyIds.removeAll()
    }
    
    private func deleteSelected() {
        let replies = viewModel.replies.filter { selectedReplyIds.contains($0.id) }
        viewModel.deleteRepliesBatch(replies)
        selectedReplyIds.removeAll()
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

