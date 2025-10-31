import SwiftUI

struct DraftsView: View {
    @StateObject private var viewModel: DraftsViewModel
    let isAuthenticated: Bool
    
    init(apiClient: APIClient, isAuthenticated: Bool) {
        _viewModel = StateObject(wrappedValue: DraftsViewModel(apiClient: apiClient))
        self.isAuthenticated = isAuthenticated
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.drafts.isEmpty {
                ProgressView("Loading drafts…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = viewModel.errorMessage, viewModel.drafts.isEmpty {
                ContentUnavailableView(
                    "No Drafts",
                    systemImage: "doc.text",
                    description: Text(message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.drafts) { draft in
                        DraftCell(draft: draft)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { viewModel.refresh() }
            }
        }
        .navigationTitle("Drafts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Menu {
                        Button("Generated") { viewModel.load(status: "generated") }
                        Button("Queued") { viewModel.load(status: "queued_twikit") }
                        Button("Failed") { viewModel.load(status: "failed") }
                        Button("Posted") { viewModel.load(status: "posted") }
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
        if viewModel.drafts.isEmpty {
            viewModel.load()
        }
    }
}

private struct DraftCell: View {
    let draft: DraftReply

    private var statusColor: Color {
        switch draft.status.lowercased() {
        case "posted": return .green
        case "failed": return .red
        case "queued_twikit": return .orange
        default: return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(draft.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.headline)
                    .foregroundColor(statusColor)
                Spacer()
                if let provider = draft.llmProvider {
                    Text(provider.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            Text(draft.text)
                .font(.body)

            if let original = draft.originalPost {
                VStack(alignment: .leading, spacing: 6) {
                    Text("In reply to @\(original.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(original.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    if let url = original.xPostURL {
                        Link("View original", destination: url)
                            .font(.caption)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            HStack {
                if let score = draft.qualityScore {
                    Label(String(format: "%.1f", score), systemImage: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }

                if let scheduled = draft.scheduledSendAt {
                    Text("Scheduled \(scheduled.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct DraftsView_Previews: PreviewProvider {
    static var previews: some View {
        DraftsView(apiClient: APIClient(), isAuthenticated: true)
    }
}


