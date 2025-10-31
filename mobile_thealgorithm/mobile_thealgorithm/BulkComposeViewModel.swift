import Foundation
import Combine
import SwiftUI

@MainActor
final class BulkComposeViewModel: ObservableObject {
    @Published var posts: [BulkComposePost] = []
    @Published var currentSession: BulkComposeSession?
    @Published var isGenerating = false
    @Published var isLoading = false
    @Published var isPublishing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showSuccessAlert = false
    @Published var showErrorAlert = false
    @Published var publishingStatus: PublishingStatus?
    
    // Selection for batch operations
    @Published var selectedPostIds: Set<String> = []
    
    private let apiClient: APIClient
    private var pollingTimer: Timer?
    
    // Computed properties
    var draftPosts: [BulkComposePost] {
        posts.filter { $0.status == "draft" }
    }
    
    var approvedPosts: [BulkComposePost] {
        posts.filter { $0.status == "approved" }
    }
    
    var scheduledPosts: [BulkComposePost] {
        posts.filter { $0.status == "scheduled" }
    }
    
    var postedPosts: [BulkComposePost] {
        posts.filter { $0.status == "posted" }
    }
    
    var rejectedPosts: [BulkComposePost] {
        posts.filter { $0.status == "rejected" }
    }
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Generation
    
    func generatePosts(prompt: String, numPosts: Int = 10) {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        
        print("🎨 [BulkCompose] Generating \(numPosts) posts from prompt: \(prompt)")
        
        apiClient.createBulkComposeSession(prompt: prompt, numPosts: numPosts) { [weak self] result in
            guard let self else { return }
            self.isGenerating = false
            
            switch result {
            case .success(let session):
                print("✅ [BulkCompose] Session created: \(session.id)")
                self.currentSession = session
                self.loadPosts(sessionId: session.id)
                
            case .failure(let error):
                print("❌ [BulkCompose] Generation failed: \(error)")
                self.errorMessage = Self.readableMessage(from: error)
                self.showErrorAlert = true
            }
        }
    }
    
    // MARK: - Loading
    
    func loadPosts(sessionId: String, status: String? = nil) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        apiClient.fetchBulkComposePosts(sessionId: sessionId, status: status) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let fetchedPosts):
                print("✅ [BulkCompose] Loaded \(fetchedPosts.count) posts")
                self.posts = fetchedPosts
                
            case .failure(let error):
                print("❌ [BulkCompose] Load failed: \(error)")
                self.errorMessage = Self.readableMessage(from: error)
            }
        }
    }
    
    func refresh() {
        if let sessionId = currentSession?.id {
            loadPosts(sessionId: sessionId)
        }
    }
    
    // MARK: - Approval
    
    func approvePost(_ post: BulkComposePost) {
        apiClient.approvePost(postId: post.id) { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .success(let updatedPost):
                print("✅ [BulkCompose] Post approved: \(post.id)")
                if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                    self.posts[index] = updatedPost
                }
                
            case .failure(let error):
                print("❌ [BulkCompose] Approve failed: \(error)")
                self.errorMessage = Self.readableMessage(from: error)
                self.showErrorAlert = true
            }
        }
    }
    
    func batchApprove() {
        guard !selectedPostIds.isEmpty else { return }
        let postIds = Array(selectedPostIds)
        
        apiClient.batchApprovePosts(postIds: postIds) { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .success(let response):
                print("✅ [BulkCompose] Batch approved: \(response.successful)/\(response.total)")
                self.successMessage = "Approved \(response.successful) of \(response.total) posts"
                self.showSuccessAlert = true
                self.selectedPostIds.removeAll()
                self.refresh()
                
            case .failure(let error):
                print("❌ [BulkCompose] Batch approve failed: \(error)")
                self.errorMessage = Self.readableMessage(from: error)
                self.showErrorAlert = true
            }
        }
    }
    
    func rejectPost(_ post: BulkComposePost) {
        apiClient.updatePost(postId: post.id, status: "rejected") { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .success(let updatedPost):
                print("✅ [BulkCompose] Post rejected: \(post.id)")
                if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                    self.posts[index] = updatedPost
                }
                
            case .failure(let error):
                print("❌ [BulkCompose] Reject failed: \(error)")
                self.errorMessage = Self.readableMessage(from: error)
                self.showErrorAlert = true
            }
        }
    }
    
    func deletePost(_ post: BulkComposePost) {
        apiClient.deletePost(postId: post.id) { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .success:
                print("✅ [BulkCompose] Post deleted: \(post.id)")
                self.posts.removeAll { $0.id == post.id }
                
            case .failure(let error):
                print("❌ [BulkCompose] Delete failed: \(error)")
                self.errorMessage = Self.readableMessage(from: error)
                self.showErrorAlert = true
            }
        }
    }
    
    // MARK: - Publishing & Scheduling
    
    func publishImmediate(postIds: [String]) {
        publishPosts(postIds: postIds, scheduleMode: "immediate")
    }
    
    func publishScheduled(postIds: [String], scheduledFor: Date) {
        publishPosts(postIds: postIds, scheduleMode: "scheduled", scheduledFor: scheduledFor)
    }
    
    func publishStaggered(postIds: [String], startTime: Date, intervalMinutes: Int) {
        publishPosts(postIds: postIds, scheduleMode: "staggered", scheduledFor: startTime, staggerIntervalMinutes: intervalMinutes)
    }
    
    func publishRandom(postIds: [String], timeWindowHours: Int, minInterval: Int, maxInterval: Int, startTime: Date? = nil) {
        guard !isPublishing else { return }
        isPublishing = true
        
        apiClient.schedulePostsRandomly(
            postIds: postIds,
            timeWindowHours: timeWindowHours,
            minIntervalMinutes: minInterval,
            maxIntervalMinutes: maxInterval,
            startTime: startTime
        ) { [weak self] result in
            guard let self else { return }
            self.isPublishing = false
            
            switch result {
            case .success(let response):
                print("✅ [BulkCompose] Random schedule: \(response.totalPosts) posts")
                self.successMessage = "Scheduled \(response.totalPosts) posts randomly"
                self.showSuccessAlert = true
                self.refresh()
                
            case .failure(let error):
                print("❌ [BulkCompose] Random schedule failed: \(error)")
                self.errorMessage = Self.readableMessage(from: error)
                self.showErrorAlert = true
            }
        }
    }
    
    private func publishPosts(postIds: [String], scheduleMode: String, scheduledFor: Date? = nil, staggerIntervalMinutes: Int? = nil) {
        guard !isPublishing else { return }
        isPublishing = true
        
        apiClient.publishPosts(
            postIds: postIds,
            scheduleMode: scheduleMode,
            scheduledFor: scheduledFor,
            staggerIntervalMinutes: staggerIntervalMinutes
        ) { [weak self] result in
            guard let self else { return }
            self.isPublishing = false
            
            switch result {
            case .success(let status):
                print("✅ [BulkCompose] Published: \(status.status.scheduled + status.status.completed) posts")
                self.publishingStatus = status
                self.successMessage = "Publishing \(status.status.scheduled + status.status.completed) posts"
                self.showSuccessAlert = true
                self.refresh()
                
                // Start polling for status updates
                if let sessionId = self.currentSession?.id {
                    self.startPollingStatus(sessionId: sessionId)
                }
                
            case .failure(let error):
                print("❌ [BulkCompose] Publish failed: \(error)")
                self.errorMessage = Self.readableMessage(from: error)
                self.showErrorAlert = true
            }
        }
    }
    
    // MARK: - Status Polling
    
    func startPollingStatus(sessionId: String) {
        stopPolling()
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            
            self.apiClient.fetchPublishingStatus(sessionId: sessionId) { result in
                switch result {
                case .success(let status):
                    self.publishingStatus = status
                    
                    // Stop polling when all jobs are done
                    if status.status.processing == 0 && status.status.queued == 0 {
                        self.stopPolling()
                        self.refresh()
                    }
                    
                case .failure:
                    // Continue polling even on errors
                    break
                }
            }
        }
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - Selection
    
    func toggleSelection(for postId: String) {
        if selectedPostIds.contains(postId) {
            selectedPostIds.remove(postId)
        } else {
            selectedPostIds.insert(postId)
        }
    }
    
    func selectAll() {
        selectedPostIds = Set(posts.map { $0.id })
    }
    
    func deselectAll() {
        selectedPostIds.removeAll()
    }
    
    // MARK: - Helper
    
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
    
    deinit {
        stopPolling()
    }
}

