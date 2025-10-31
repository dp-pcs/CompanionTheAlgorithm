import Foundation
import Combine
import SwiftUI

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [FeedPost] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var lastFetchSummary: String?
    
    // Selection & Bulk Operations
    @Published var selectedPostIds: Set<String> = []
    @Published var isBulkGenerating = false
    @Published var isBulkLiking = false
    @Published var showSuccessAlert = false
    @Published var showErrorAlert = false
    @Published var successMessage: String?
    @Published var bulkErrorMessage: String?

    private let apiClient: APIClient
    private var monitoringStatus: MonitoringStatus?
    private var hasAttemptedAutoTimelineFetch = false

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load(limit: Int = 25) {
        guard !isLoading else { return }
        isLoading = true
        infoMessage = nil
        errorMessage = nil

        fetchMonitoringStatus(limit: limit)
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        infoMessage = nil
        errorMessage = nil

        debugLog("Refreshing feed…")
        fetchMonitoringStatus(limit: max(posts.count, 25))
    }

    func fetchTimeline(count: Int = 40) {
        guard !isRefreshing else { return }
        isRefreshing = true
        infoMessage = "Fetching timeline from X.com…"
        errorMessage = nil
        lastFetchSummary = nil

        debugLog("Fetching timeline (count=\(count))")
        apiClient.fetchTimeline(count: count) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let response):
                self.lastFetchSummary = "Fetched \(response.fetched) posts (\(response.newPosts) new, \(response.updatedPosts) updated)"
                self.debugLog("Timeline fetch succeeded: \(response)")
                self.fetchMonitoringStatus(limit: max(self.posts.count, 25))
            case .failure(let error):
                self.debugLog("Timeline fetch failed: \(error)")
                self.isRefreshing = false
                self.errorMessage = Self.readableMessage(from: error)
                if self.posts.isEmpty {
                    self.infoMessage = "No recent posts found. Use Fetch Timeline to pull in the latest tweets."
                }
            }
        }
    }

    private func fetchMonitoringStatus(limit: Int) {
        apiClient.fetchMonitoringStatus { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            self.isRefreshing = false

            switch result {
            case .success(let status):
                self.debugLog("Monitoring status fetched. recentPosts=\(status.recentPosts.count)")
                self.monitoringStatus = status
                let posts = Array(status.recentPosts.prefix(limit))
                self.posts = posts

                if posts.isEmpty {
                    if !self.hasAttemptedAutoTimelineFetch {
                        self.hasAttemptedAutoTimelineFetch = true
                        self.infoMessage = "Fetching your timeline from X.com…"
                        self.fetchTimeline()
                        return
                    } else {
                        self.infoMessage = "No recent posts found. Use Fetch Timeline to pull in the latest tweets."
                        self.debugLog("Monitoring status returned no posts even after timeline fetch.")
                    }
                } else {
                    self.infoMessage = nil
                    self.hasAttemptedAutoTimelineFetch = false
                }
            case .failure(let error):
                self.debugLog("Monitoring status failed: \(error)")
                self.errorMessage = Self.readableMessage(from: error)
            }
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

    private func debugLog(_ message: String) {
#if DEBUG
        print("🗒️ [FeedViewModel] \(message)")
#endif
    }
    
    // MARK: - Selection & Bulk Operations
    
    func toggleSelection(for postId: String) {
        if selectedPostIds.contains(postId) {
            selectedPostIds.remove(postId)
        } else {
            selectedPostIds.insert(postId)
        }
    }
    
    func toggleSelectAll() {
        if selectedPostIds.count == posts.count {
            selectedPostIds.removeAll()
        } else {
            selectedPostIds = Set(posts.map { $0.id })
        }
    }
    
    func bulkGenerateReplies() {
        guard !selectedPostIds.isEmpty, !isBulkGenerating else { return }
        
        isBulkGenerating = true
        let postIds = Array(selectedPostIds)
        
        debugLog("🌟 Bulk generating replies for \(postIds.count) posts")
        
        apiClient.bulkGenerateReplies(postIds: postIds) { [weak self] result in
            guard let self else { return }
            self.isBulkGenerating = false
            
            switch result {
            case .success(let response):
                self.debugLog("✅ Bulk generate succeeded: \(response.successful)/\(response.total)")
                
                // Update post statuses to 'generated' for successful ones
                let successfulIds = Set(response.results.filter { $0.success }.map { $0.postId })
                self.posts = self.posts.map { post in
                    if successfulIds.contains(post.id) {
                        var updatedPost = post
                        updatedPost.replyStatus = "generated"
                        return updatedPost
                    }
                    return post
                }
                
                // Clear selection
                self.selectedPostIds.removeAll()
                
                // Show success message
                self.successMessage = "✓ Generated \(response.successful) of \(response.total) replies! Check History to review."
                self.showSuccessAlert = true
                
                // Refresh to get latest status
                self.refresh()
                
            case .failure(let error):
                self.debugLog("❌ Bulk generate failed: \(error)")
                self.bulkErrorMessage = Self.readableMessage(from: error)
                self.showErrorAlert = true
            }
        }
    }
    
    func bulkLikePosts() {
        guard !selectedPostIds.isEmpty, !isBulkLiking else { return }
        
        isBulkLiking = true
        
        // Extract tweet IDs from selected posts
        let selectedPosts = posts.filter { selectedPostIds.contains($0.id) }
        let tweetIds = selectedPosts.compactMap { post -> String? in
            guard let urlString = post.url?.absoluteString else { return nil }
            // Extract tweet ID from URL like https://x.com/username/status/1234567890
            if let range = urlString.range(of: "/status/") {
                let idString = String(urlString[range.upperBound...])
                // Remove any query parameters
                if let endIndex = idString.firstIndex(of: "?") {
                    return String(idString[..<endIndex])
                }
                return idString
            }
            return nil
        }
        
        debugLog("❤️ Bulk liking \(tweetIds.count) tweets")
        
        apiClient.bulkLikeTweets(tweetIds: tweetIds) { [weak self] result in
            guard let self else { return }
            self.isBulkLiking = false
            
            switch result {
            case .success(let response):
                self.debugLog("✅ Bulk like succeeded: \(response.successful)/\(response.total)")
                
                // Clear selection
                self.selectedPostIds.removeAll()
                
                // Show success message
                self.successMessage = "✓ Liked \(response.successful) of \(response.total) tweets!"
                self.showSuccessAlert = true
                
            case .failure(let error):
                self.debugLog("❌ Bulk like failed: \(error)")
                self.bulkErrorMessage = Self.readableMessage(from: error)
                self.showErrorAlert = true
            }
        }
    }
}


