import Foundation
import Combine
import SwiftUI

@MainActor
final class ReplyQueueViewModel: ObservableObject {
    @Published var replies: [DraftReply] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Filter states
    @Published var selectedStatus: String = "generated"
    
    private let apiClient: APIClient
    
    // Computed properties
    var queuedCount: Int {
        replies.filter { $0.status.lowercased() == "generated" || $0.status.lowercased() == "queued" }.count
    }
    
    var totalCount: Int {
        replies.count
    }
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func load(status: String? = nil) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        let statusFilter = status ?? selectedStatus
        
        apiClient.fetchDraftReplies(status: statusFilter) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let fetchedReplies):
                self.replies = fetchedReplies
                print("✅ Loaded \(fetchedReplies.count) replies with status: \(statusFilter)")
            case .failure(let error):
                print("❌ Failed to load replies: \(error)")
                self.errorMessage = Self.readableMessage(from: error)
            }
        }
    }
    
    func refresh(status: String? = nil) {
        load(status: status)
    }
    
    func changeStatus(to status: String) {
        selectedStatus = status
        load(status: status)
    }
    
    private static func readableMessage(from error: Error) -> String {
        if let apiError = error as? APIClientError {
            switch apiError {
            case .invalidURL:
                return "Invalid API endpoint"
            case .missingAuthToken:
                return "Authentication token missing"
            case .decodingFailed(let inner):
                return "Unable to decode response: \(inner.localizedDescription)"
            case .requestFailed(let message):
                return message
            }
        }
        
        return error.localizedDescription
    }
}

