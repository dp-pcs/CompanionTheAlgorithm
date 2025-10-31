import Foundation
import Combine
import SwiftUI

@MainActor
final class DraftsViewModel: ObservableObject {
    @Published var drafts: [DraftReply] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentStatusFilter: String = "generated"

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load(status: String? = nil) {
        let filter = status ?? currentStatusFilter
        currentStatusFilter = filter

        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        apiClient.fetchDraftReplies(status: filter) { [weak self] result in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case .success(let replies):
                self.drafts = replies
            case .failure(let error):
                self.errorMessage = Self.readableMessage(from: error)
            }
        }
    }

    func refresh() {
        load(status: currentStatusFilter)
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


