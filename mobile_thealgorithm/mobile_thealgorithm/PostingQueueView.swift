import SwiftUI

struct PostingQueueView: View {
    @StateObject private var viewModel: PostingQueueViewModel
    let isAuthenticated: Bool
    
    init(apiClient: APIClient, isAuthenticated: Bool) {
        _viewModel = StateObject(wrappedValue: PostingQueueViewModel(apiClient: apiClient))
        self.isAuthenticated = isAuthenticated
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.jobs.isEmpty {
                ProgressView("Loading queue…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = viewModel.errorMessage, viewModel.jobs.isEmpty {
                ContentUnavailableView(
                    "No Jobs",
                    systemImage: "tray",
                    description: Text(message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Summary") {
                        HStack {
                            Text("Total jobs")
                            Spacer()
                            Text("\(viewModel.totalJobs)")
                                .foregroundColor(.secondary)
                        }
                    }

                    Section("Jobs") {
                        ForEach(viewModel.jobs) { job in
                            PostingJobCell(job: job)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { viewModel.refresh() }
            }
        }
        .navigationTitle("Posting Queue")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Menu {
                        Button("All") { viewModel.load(status: nil) }
                        Button("Queued") { viewModel.load(status: "queued") }
                        Button("Processing") { viewModel.load(status: "processing") }
                        Button("Completed") { viewModel.load(status: "completed") }
                        Button("Failed") { viewModel.load(status: "failed") }
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
        guard isAuthenticated else { return }
        if viewModel.jobs.isEmpty {
            viewModel.load()
        }
    }
}

private struct PostingJobCell: View {
    let job: PostingJob

    private var statusColor: Color {
        switch job.status.lowercased() {
        case "completed": return .green
        case "failed": return .red
        case "processing": return .orange
        case "queued": return .blue
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(job.jobType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.headline)
                Spacer()
                Text(job.status.capitalized)
                    .font(.subheadline)
                    .foregroundColor(statusColor)
            }

            ProgressView(value: Double(job.progressPercentage), total: 100)

            HStack(spacing: 12) {
                Label("\(job.processedItems)/\(job.totalItems)", systemImage: "checkmark.circle")
                Label("+\(job.successfulItems)", systemImage: "arrow.up")
                Label("-\(job.failedItems)", systemImage: "xmark")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if let message = job.errorMessage, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if let createdAt = job.createdAt {
                Text("Started \(createdAt.formatted(.relative(presentation: .numeric)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct PostingQueueView_Previews: PreviewProvider {
    static var previews: some View {
        PostingQueueView(apiClient: APIClient(), isAuthenticated: true)
    }
}


