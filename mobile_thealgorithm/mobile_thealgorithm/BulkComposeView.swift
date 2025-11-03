import SwiftUI

struct BulkComposeView: View {
    @StateObject private var viewModel: BulkComposeViewModel
    let isAuthenticated: Bool
    
    @State private var promptText: String = ""
    @State private var numPosts: Int = 10
    @State private var showSchedulingSheet = false
    @State private var postsToSchedule: [String] = []
    
    init(apiClient: APIClient, isAuthenticated: Bool) {
        _viewModel = StateObject(wrappedValue: BulkComposeViewModel(apiClient: apiClient))
        self.isAuthenticated = isAuthenticated
    }
    
    var body: some View {
        Group {
            if viewModel.isGenerating {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Generating posts...")
                        .font(.headline)
                    Text("This may take a moment")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.currentSession == nil {
                promptInputView
            } else {
                postsListView
            }
        }
        .navigationTitle("My Posts")
        .alert("Success", isPresented: $viewModel.showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showSchedulingSheet) {
            SchedulingSheet(
                viewModel: viewModel,
                postIds: postsToSchedule,
                isPresented: $showSchedulingSheet
            )
        }
    }
    
    // MARK: - Prompt Input View
    
    private var promptInputView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Generate Posts with AI")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter a prompt to generate multiple posts. The AI will create unique variations based on your topic.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Prompt")
                        .font(.headline)
                    
                    TextEditor(text: $promptText)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    
                    Text("Example: \"Write 10 tweets about AI trends in 2025\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Number of Posts")
                        .font(.headline)
                    
                    Stepper("\(numPosts) posts", value: $numPosts, in: 5...20)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Button(action: generatePosts) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Generate Posts")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(promptText.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(promptText.isEmpty)
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Posts List View
    
    private var postsListView: some View {
        List {
            // Publishing Status
            if let status = viewModel.publishingStatus, status.status.publishing > 0 || status.status.pending > 0 {
                Section {
                    PublishingStatusView(status: status)
                }
            }
            
            // Draft Posts
            if !viewModel.draftPosts.isEmpty {
                Section {
                    ForEach(viewModel.draftPosts) { post in
                        PostCell(
                            post: post,
                            viewModel: viewModel,
                            onApprove: { viewModel.approvePost(post) },
                            onReject: { viewModel.rejectPost(post) },
                            onDelete: { viewModel.deletePost(post) }
                        )
                    }
                } header: {
                    HStack {
                        Text("Drafts")
                        Spacer()
                        Text("\(viewModel.draftPosts.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Approved Posts (Ready to Schedule)
            if !viewModel.approvedPosts.isEmpty {
                Section {
                    ForEach(viewModel.approvedPosts) { post in
                        PostCell(
                            post: post,
                            viewModel: viewModel,
                            onDelete: { viewModel.deletePost(post) },
                            onSchedule: {
                                postsToSchedule = [post.id]
                                showSchedulingSheet = true
                            }
                        )
                    }
                } header: {
                    HStack {
                        Text("Approved (Ready to Schedule)")
                        Spacer()
                        Text("\(viewModel.approvedPosts.count)")
                            .foregroundColor(.blue)
                    }
                } footer: {
                    if viewModel.approvedPosts.count > 0 {
                        VStack(spacing: 12) {
                            // Publish Immediately
                            Button(action: publishAllApprovedNow) {
                                HStack {
                                    Image(systemName: "paperplane.fill")
                                    Text("Publish All Approved Posts Now")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            // Schedule
                            Button(action: scheduleAllApproved) {
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                    Text("Schedule All Approved Posts")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowInsets(EdgeInsets())
                        .padding(.top, 8)
                    }
                }
            }
            
            // Scheduled Posts
            if !viewModel.scheduledPosts.isEmpty {
                Section {
                    ForEach(viewModel.scheduledPosts) { post in
                        PostCell(
                            post: post,
                            viewModel: viewModel,
                            onCancel: { viewModel.deletePost(post) }
                        )
                    }
                } header: {
                    HStack {
                        Text("Scheduled")
                        Spacer()
                        Text("\(viewModel.scheduledPosts.count)")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Posted
            if !viewModel.postedPosts.isEmpty {
                Section {
                    ForEach(viewModel.postedPosts) { post in
                        PostCell(post: post, viewModel: viewModel)
                    }
                } header: {
                    HStack {
                        Text("Posted")
                        Spacer()
                        Text("\(viewModel.postedPosts.count)")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            viewModel.refresh()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: startNewSession) {
                        Label("New Session", systemImage: "plus.circle")
                    }
                    Divider()
                    Button(action: { viewModel.refresh() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func generatePosts() {
        viewModel.generatePosts(prompt: promptText, numPosts: numPosts)
    }
    
    private func scheduleAllApproved() {
        postsToSchedule = viewModel.approvedPosts.map { $0.id }
        showSchedulingSheet = true
    }
    
    private func publishAllApprovedNow() {
        let postIds = viewModel.approvedPosts.map { $0.id }
        viewModel.publishImmediate(postIds: postIds)
    }
    
    private func startNewSession() {
        viewModel.currentSession = nil
        viewModel.posts = []
        promptText = ""
    }
}

// MARK: - Post Cell

private struct PostCell: View {
    let post: BulkComposePost
    @ObservedObject var viewModel: BulkComposeViewModel
    
    var onApprove: (() -> Void)? = nil
    var onReject: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onSchedule: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil
    
    private var statusColor: Color {
        switch post.status {
        case "posted": return .green
        case "scheduled": return .orange
        case "approved": return .blue
        case "rejected": return .red
        case "failed": return .red
        default: return .gray
        }
    }
    
    private var statusIcon: String {
        switch post.status {
        case "posted": return "checkmark.circle.fill"
        case "scheduled": return "clock.fill"
        case "approved": return "checkmark.circle"
        case "rejected": return "xmark.circle"
        case "failed": return "exclamationmark.triangle.fill"
        default: return "doc.text"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status Badge
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text(post.status.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                
                Spacer()
                
                if let scheduledFor = post.scheduledFor {
                    Text(scheduledFor, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Post Text
            Text(post.text)
                .font(.body)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            // Metadata
            HStack(spacing: 16) {
                if let score = post.engagementScore {
                    Label(String(format: "%.1f", score), systemImage: "chart.bar.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                if let createdAt = post.createdAt {
                    Text(createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let postUrl = post.postUrl, let url = URL(string: postUrl) {
                    Link("View Post", destination: url)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            if let onCancel = onCancel {
                Button(action: onCancel) {
                    Label("Cancel", systemImage: "xmark")
                }
                .tint(.orange)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if let onApprove = onApprove {
                Button(action: onApprove) {
                    Label("Approve", systemImage: "checkmark")
                }
                .tint(.green)
            }
            
            if let onSchedule = onSchedule {
                Button(action: onSchedule) {
                    Label("Schedule", systemImage: "calendar")
                }
                .tint(.blue)
            }
            
            if let onReject = onReject {
                Button(action: onReject) {
                    Label("Reject", systemImage: "xmark")
                }
                .tint(.red)
            }
        }
    }
}

// MARK: - Publishing Status View

private struct PublishingStatusView: View {
    let status: PublishingStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Publishing Progress")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatusBadge(count: status.status.pending, label: "Pending", color: .gray)
                StatusBadge(count: status.status.publishing, label: "Publishing", color: .blue)
                StatusBadge(count: status.status.scheduled, label: "Scheduled", color: .orange)
            }
            
            HStack(spacing: 20) {
                StatusBadge(count: status.status.published, label: "Published", color: .green)
                StatusBadge(count: status.status.failed, label: "Failed", color: .red)
            }
            
            if status.status.publishing > 0 {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

private struct StatusBadge: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Scheduling Sheet

struct SchedulingSheet: View {
    @ObservedObject var viewModel: BulkComposeViewModel
    let postIds: [String]
    @Binding var isPresented: Bool
    
    @State private var selectedMode: ScheduleMode = .immediate
    @State private var scheduledDate = Date().addingTimeInterval(3600) // 1 hour from now
    @State private var staggerInterval = 30
    @State private var timeWindowHours = 6
    @State private var minInterval = 15
    @State private var maxInterval = 45
    
    enum ScheduleMode: String, CaseIterable {
        case immediate = "Post Now"
        case scheduled = "Schedule"
        case staggered = "Stagger"
        case random = "Random"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Publishing Mode", selection: $selectedMode) {
                        ForEach(ScheduleMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Choose Publishing Method")
                }
                
                switch selectedMode {
                case .immediate:
                    Section {
                        Text("Posts will be published immediately")
                            .foregroundColor(.secondary)
                    }
                    
                case .scheduled:
                    Section {
                        DatePicker("Schedule For", selection: $scheduledDate, in: Date()...)
                    } footer: {
                        Text("All \(postIds.count) posts will be published at this time")
                    }
                    
                case .staggered:
                    Section {
                        DatePicker("Start Time", selection: $scheduledDate, in: Date()...)
                        Stepper("Interval: \(staggerInterval) min", value: $staggerInterval, in: 5...120, step: 5)
                    } footer: {
                        Text("Posts will be published every \(staggerInterval) minutes starting at the selected time")
                    }
                    
                case .random:
                    Section {
                        DatePicker("Start Time", selection: $scheduledDate, in: Date()...)
                        Stepper("Time Window: \(timeWindowHours) hours", value: $timeWindowHours, in: 1...24)
                        Stepper("Min Interval: \(minInterval) min", value: $minInterval, in: 5...60, step: 5)
                        Stepper("Max Interval: \(maxInterval) min", value: $maxInterval, in: minInterval...120, step: 5)
                    } footer: {
                        Text("Posts will be published at random times within \(timeWindowHours) hours, with \(minInterval)-\(maxInterval) minute intervals")
                    }
                }
                
                Section {
                    Button(action: scheduleNow) {
                        HStack {
                            Spacer()
                            if viewModel.isPublishing {
                                ProgressView()
                            } else {
                                Text("Schedule \(postIds.count) Posts")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isPublishing)
                }
            }
            .navigationTitle("Schedule Posts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func scheduleNow() {
        switch selectedMode {
        case .immediate:
            viewModel.publishImmediate(postIds: postIds)
        case .scheduled:
            viewModel.publishScheduled(postIds: postIds, scheduledFor: scheduledDate)
        case .staggered:
            viewModel.publishStaggered(postIds: postIds, startTime: scheduledDate, intervalMinutes: staggerInterval)
        case .random:
            viewModel.publishRandom(
                postIds: postIds,
                timeWindowHours: timeWindowHours,
                minInterval: minInterval,
                maxInterval: maxInterval,
                startTime: scheduledDate
            )
        }
        
        isPresented = false
    }
}

