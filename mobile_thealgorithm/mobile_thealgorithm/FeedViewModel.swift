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
}


