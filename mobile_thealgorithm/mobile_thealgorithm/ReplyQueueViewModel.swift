import Foundation
import Combine
import SwiftUI

@MainActor
final class ReplyQueueViewModel: ObservableObject {
    @Published var replies: [DraftReply] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessMessage = false
    @Published var successMessage: String = ""
    
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
    
    func sendReplyNow(_ reply: DraftReply) {
        print("📤 [ReplyQueue] Sending reply now: \(reply.id)")
        
        guard let replyText = reply.replyText, !replyText.isEmpty else {
            errorMessage = "Reply has no text to send"
            return
        }
        
        isLoading = true
        
        apiClient.postReply(replyId: reply.id, text: replyText) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            
            switch result {
            case .success:
                print("✅ [ReplyQueue] Reply posted successfully!")
                // Remove from local list and refresh
                self.replies.removeAll { $0.id == reply.id }
                self.successMessage = "Reply sent to Twitter! 🎉"
                self.showSuccessMessage = true
                self.refresh()
            case .failure(let error):
                print("❌ [ReplyQueue] Failed to post reply: \(error)")
                self.errorMessage = "Failed to send reply: \(error.localizedDescription)"
            }
        }
    }
    
    func scheduleReply(_ reply: DraftReply) {
        print("📅 [ReplyQueue] Scheduling reply: \(reply.id)")
        isLoading = true
        
        // Schedule with default settings: 24hr window, 30-120 min intervals
        apiClient.scheduleReplyRandom(
            replyId: reply.id,
            timeWindowHours: 24,
            minIntervalMinutes: 30,
            maxIntervalMinutes: 120
        ) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            
            switch result {
            case .success:
                print("✅ [ReplyQueue] Reply scheduled successfully!")
                // Remove from current list and refresh
                self.replies.removeAll { $0.id == reply.id }
                self.successMessage = "Reply scheduled! 📅"
                self.showSuccessMessage = true
                self.refresh()
            case .failure(let error):
                print("❌ [ReplyQueue] Failed to schedule reply: \(error)")
                self.errorMessage = "Failed to schedule reply: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteReply(_ reply: DraftReply) {
        print("🗑️ [ReplyQueue] Deleting reply: \(reply.id)")
        isLoading = true
        
        apiClient.deleteReply(replyId: reply.id) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            
            switch result {
            case .success:
                print("✅ [ReplyQueue] Reply deleted successfully!")
                self.replies.removeAll { $0.id == reply.id }
            case .failure(let error):
                print("❌ [ReplyQueue] Failed to delete reply: \(error)")
                self.errorMessage = "Failed to delete reply: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Batch Operations
    
    func sendRepliesBatch(_ replies: [DraftReply]) {
        print("📤 [ReplyQueue] Batch sending \(replies.count) replies")
        isLoading = true
        
        let group = DispatchGroup()
        var successCount = 0
        var failCount = 0
        
        for reply in replies {
            guard let replyText = reply.replyText, !replyText.isEmpty else {
                failCount += 1
                continue
            }
            
            group.enter()
            apiClient.postReply(replyId: reply.id, text: replyText) { [weak self] result in
                switch result {
                case .success:
                    successCount += 1
                    self?.replies.removeAll { $0.id == reply.id }
                case .failure:
                    failCount += 1
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            if successCount > 0 {
                self?.successMessage = "✅ Sent \(successCount) replies to Twitter!"
                self?.showSuccessMessage = true
            }
            if failCount > 0 {
                self?.errorMessage = "Sent \(successCount) replies, \(failCount) failed"
            }
            print("✅ [ReplyQueue] Batch send complete: \(successCount) success, \(failCount) failed")
            self?.refresh()
        }
    }
    
    func scheduleRepliesBatch(_ replies: [DraftReply]) {
        print("📅 [ReplyQueue] Batch scheduling \(replies.count) replies")
        isLoading = true
        
        let group = DispatchGroup()
        var successCount = 0
        var failCount = 0
        
        for reply in replies {
            group.enter()
            apiClient.scheduleReplyRandom(
                replyId: reply.id,
                timeWindowHours: 24,
                minIntervalMinutes: 30,
                maxIntervalMinutes: 120
            ) { [weak self] result in
                switch result {
                case .success:
                    successCount += 1
                    self?.replies.removeAll { $0.id == reply.id }
                case .failure:
                    failCount += 1
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            if successCount > 0 {
                self?.successMessage = "✅ Scheduled \(successCount) replies!"
                self?.showSuccessMessage = true
            }
            if failCount > 0 {
                self?.errorMessage = "Scheduled \(successCount) replies, \(failCount) failed"
            }
            print("✅ [ReplyQueue] Batch schedule complete: \(successCount) success, \(failCount) failed")
            self?.refresh()
        }
    }
    
    func deleteRepliesBatch(_ replies: [DraftReply]) {
        print("🗑️ [ReplyQueue] Batch deleting \(replies.count) replies")
        isLoading = true
        
        let group = DispatchGroup()
        var successCount = 0
        var failCount = 0
        
        for reply in replies {
            group.enter()
            apiClient.deleteReply(replyId: reply.id) { [weak self] result in
                switch result {
                case .success:
                    successCount += 1
                    self?.replies.removeAll { $0.id == reply.id }
                case .failure:
                    failCount += 1
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            if failCount > 0 {
                self?.errorMessage = "Deleted \(successCount) replies, \(failCount) failed"
            }
            print("✅ [ReplyQueue] Batch delete complete: \(successCount) success, \(failCount) failed")
        }
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

