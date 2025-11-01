import Foundation
import Combine
import SwiftUI

@MainActor
final class ReplyQueueViewModel: ObservableObject {
    @Published var replies: [DraftReply] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Filter states
    @Published var selectedStatus: String = "queued"  // Default to "queued" since bulk-generated replies start as queued
    
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
        print("🎯 [ReplyQueue] ViewModel initialized")
    }
    
    func load(status: String? = nil) {
        let statusFilter = status ?? selectedStatus
        print("🎯 [ReplyQueue] load() called with status: \(statusFilter)")
        
        guard !isLoading else {
            print("🎯 [ReplyQueue] Already loading, skipping")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("🎯 [ReplyQueue] Starting API call to fetch replies (status=\(statusFilter))")
        
        apiClient.fetchDraftReplies(status: statusFilter) { [weak self] result in
            guard let self else {
                print("🎯 [ReplyQueue] ❌ self was deallocated before completion")
                return
            }
            
            print("🎯 [ReplyQueue] API call completed")
            self.isLoading = false
            
            switch result {
            case .success(let fetchedReplies):
                self.replies = fetchedReplies
                print("🎯 [ReplyQueue] ✅ Loaded \(fetchedReplies.count) replies with status: \(statusFilter)")
            case .failure(let error):
                print("🎯 [ReplyQueue] ❌ Failed to load replies: \(error)")
                self.errorMessage = Self.readableMessage(from: error)
            }
        }
    }
    
    func refresh(status: String? = nil) {
        print("🎯 [ReplyQueue] refresh() called with status: \(status ?? "nil")")
        load(status: status)
    }
    
    func changeStatus(to status: String) {
        print("🎯 [ReplyQueue] changeStatus() called, changing to: \(status)")
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

