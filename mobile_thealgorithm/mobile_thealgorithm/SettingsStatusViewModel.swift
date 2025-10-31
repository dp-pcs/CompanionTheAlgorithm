import Foundation
import Combine
import SwiftUI
import Combine

@MainActor
final class SettingsStatusViewModel: ObservableObject {
    @Published var status: SettingsStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        apiClient.fetchSettingsStatus { [weak self] result in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case .success(let status):
                self.status = status
            case .failure(let error):
                self.errorMessage = Self.readableMessage(from: error)
            }
        }
    }

    func refresh() {
        load()
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


