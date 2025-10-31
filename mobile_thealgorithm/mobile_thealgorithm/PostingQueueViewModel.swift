import Foundation
import Combine
import SwiftUI

@MainActor
final class PostingQueueViewModel: ObservableObject {
    @Published var jobs: [PostingJob] = []
    @Published var totalJobs: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load(status: String? = nil) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        apiClient.fetchPostingJobs(status: status) { [weak self] result in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case .success(let response):
                self.jobs = response.jobs
                self.totalJobs = response.total
            case .failure(let error):
                self.errorMessage = Self.readableMessage(from: error)
            }
        }
    }

    func refresh(status: String? = nil) {
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


