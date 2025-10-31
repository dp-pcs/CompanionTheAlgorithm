import Foundation

// MARK: - Shared Helpers

private enum DateParsing {
    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let fractionalISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let microsecondFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter
    }()

    static let millisecondFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        if let date = fractionalISOFormatter.date(from: value) ?? isoFormatter.date(from: value) {
            return date
        }

        if let date = microsecondFormatter.date(from: value) ?? millisecondFormatter.date(from: value) {
            return date
        }

        return nil
    }
}

// MARK: - API Models

struct FeedMedia: Codable {
    let type: String
    let url: URL?
    let previewURL: URL?
    let videoURL: URL?

    enum CodingKeys: String, CodingKey {
        case type
        case url
        case previewURL = "preview_url"
        case videoURL = "video_url"
    }
}

struct FeedEngagement: Codable {
    let likes: Int
    let retweets: Int
    let replies: Int
}

struct FeedPost: Codable, Identifiable {
    let id: String
    let text: String
    let username: String
    let authorUsername: String
    let authorName: String?
    let authorProfileImage: URL?
    let authorVerified: Bool
    let listSource: String?
    let sourceType: String?
    let createdAt: Date?
    let engagement: FeedEngagement
    let media: [FeedMedia]
    let isRetweet: Bool
    let isReply: Bool
    let replyText: String?
    var replyStatus: String  // Changed to var to allow updates after bulk operations
    let replyId: String?
    let url: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case username
        case authorUsername = "author_username"
        case authorName = "author_name"
        case authorProfileImage = "author_profile_image"
        case authorVerified = "author_verified"
        case listSource = "list_source"
        case sourceType = "source_type"
        case createdAt = "created_at"
        case engagement
        case media
        case isRetweet = "is_retweet"
        case isReply = "is_reply"
        case replyText = "reply_text"
        case replyStatus = "reply_status"
        case replyId = "reply_id"
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        authorUsername = try container.decodeIfPresent(String.self, forKey: .authorUsername) ?? ""
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)

        if let profileString = try container.decodeIfPresent(String.self, forKey: .authorProfileImage) {
            authorProfileImage = URL(string: profileString)
        } else {
            authorProfileImage = nil
        }

        authorVerified = try container.decodeIfPresent(Bool.self, forKey: .authorVerified) ?? false
        listSource = try container.decodeIfPresent(String.self, forKey: .listSource)
        sourceType = try container.decodeIfPresent(String.self, forKey: .sourceType)
        createdAt = container.decodeDateIfPresent(forKey: .createdAt)
        engagement = try container.decodeIfPresent(FeedEngagement.self, forKey: .engagement) ?? FeedEngagement(likes: 0, retweets: 0, replies: 0)
        media = try container.decodeIfPresent([FeedMedia].self, forKey: .media) ?? []
        isRetweet = try container.decodeIfPresent(Bool.self, forKey: .isRetweet) ?? false
        isReply = try container.decodeIfPresent(Bool.self, forKey: .isReply) ?? false
        replyText = try container.decodeIfPresent(String.self, forKey: .replyText)
        replyStatus = try container.decodeIfPresent(String.self, forKey: .replyStatus) ?? "none"
        replyId = try container.decodeIfPresent(String.self, forKey: .replyId)

        if let urlString = try container.decodeIfPresent(String.self, forKey: .url) {
            url = URL(string: urlString)
        } else {
            url = nil
        }
    }
}

struct PostingJob: Codable, Identifiable {
    let id: String
    let jobType: String
    let status: String
    let totalItems: Int
    let processedItems: Int
    let successfulItems: Int
    let failedItems: Int
    let progressPercentage: Int
    let errorMessage: String?
    let createdAt: Date?
    let startedAt: Date?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case jobType = "job_type"
        case status
        case totalItems = "total_items"
        case processedItems = "processed_items"
        case successfulItems = "successful_items"
        case failedItems = "failed_items"
        case progressPercentage = "progress_percentage"
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

struct PostingJobListResponse: Codable {
    let jobs: [PostingJob]
    let total: Int
    let offset: Int
    let limit: Int
}

struct DraftReply: Codable, Identifiable {
    struct OriginalPost: Codable {
        let id: String
        let text: String
        let username: String
        let createdAt: Date?
        let xPostURL: URL?

        enum CodingKeys: String, CodingKey {
            case id
            case text
            case username
            case createdAt = "created_at"
            case xPostURL = "x_post_url"
        }
    }

    let id: String
    let postId: String
    let text: String
    let status: String
    let llmProvider: String?
    let llmModel: String?
    let generatedAt: Date?
    let qualityScore: Double?
    let scheduledSendAt: Date?
    let failureReason: String?
    let originalPost: OriginalPost?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case text
        case status
        case llmProvider = "llm_provider"
        case llmModel = "llm_model"
        case generatedAt = "generated_at"
        case qualityScore = "quality_score"
        case scheduledSendAt = "scheduled_send_at"
        case failureReason = "failure_reason"
        case originalPost = "original_post"
    }
}

struct MonitoredUser: Codable, Identifiable {
    let id: String
    let username: String
    let displayName: String?
    let isActive: Bool
    let postsMonitored: Int
    let lastPostAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username = "x_username"
        case displayName = "x_display_name"
        case isActive = "is_active"
        case postsMonitored = "posts_monitored"
        case lastPostAt = "last_post_at"
    }
}

struct SettingsStatus: Codable {
    struct LLMProviders: Codable {
        let openai: Bool
        let anthropic: Bool
        let google: Bool
    }

    struct OAuthStatus: Codable {
        let xConnected: Bool
        let googleConnected: Bool

        enum CodingKeys: String, CodingKey {
            case xConnected = "x_connected"
            case googleConnected = "google_connected"
        }
    }

    struct CurrentUserStatus: Codable {
        let isAdmin: Bool

        enum CodingKeys: String, CodingKey {
            case isAdmin = "is_admin"
        }
    }

    struct SystemStatus: Codable {
        let xAPIAvailable: Bool

        enum CodingKeys: String, CodingKey {
            case xAPIAvailable = "x_api_available"
        }
    }

    let llmProviders: LLMProviders
    let oauth: OAuthStatus
    let currentUser: CurrentUserStatus
    let system: SystemStatus

    enum CodingKeys: String, CodingKey {
        case llmProviders = "llm_providers"
        case oauth
        case currentUser = "current_user"
        case system
    }
}

struct MonitoringStatus: Codable {
    struct EngagementSettings: Codable {
        let currentUserUsername: String?

        enum CodingKeys: String, CodingKey {
            case currentUserUsername = "current_user_username"
        }
    }

    let isMonitoring: Bool
    let monitoredUsersCount: Int
    let monitoredUsernames: [String]
    let engagementSettings: EngagementSettings?
    let recentPosts: [FeedPost]

    enum CodingKeys: String, CodingKey {
        case isMonitoring = "is_monitoring"
        case monitoredUsersCount = "monitored_users_count"
        case monitoredUsernames = "monitored_usernames"
        case engagementSettings = "engagement_settings"
        case recentPosts = "recent_posts"
    }
}

struct TimelineFetchResponse: Codable {
    let fetched: Int
    let newPosts: Int
    let updatedPosts: Int

    enum CodingKeys: String, CodingKey {
        case fetched
        case newPosts = "new_posts"
        case updatedPosts = "updated_posts"
    }
}

struct BulkOperationResponse: Codable {
    let total: Int
    let successful: Int
    let failed: Int
    let results: [BulkOperationResult]
}

struct BulkOperationResult: Codable {
    let postId: String
    let success: Bool
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case success
        case message
    }
}

enum APIClientError: Error {
    case invalidURL
    case missingAuthToken
    case decodingFailed(Error)
    case requestFailed(String)
}

// MARK: - API Client

class APIClient {

    // MARK: Configuration

    private let baseURL = URL(string: "https://thealgorithm.live")!

    private let session: URLSession
    private let authManager = AuthenticationManager()
    private let cookieManager = CookieManager()
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = DateParsing.parse(value) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date format: \(value)")
        }
    }

    // MARK: Cookie Management

    func storeCookies(_ cookies: [HTTPCookie], completion: @escaping (Bool, Error?) -> Void) {
        guard authManager.getOAuthToken() != nil else {
            completion(false, NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No OAuth token available"]))
            return
        }

        let cookieData = cookies.map { cookie in
            let expiresInterval = cookie.expiresDate?.timeIntervalSince1970 ?? 0
            return [
                "name": cookie.name,
                "value": cookie.value,
                "domain": cookie.domain,
                "path": cookie.path,
                "expires": Int(expiresInterval),
                "httpOnly": cookie.isHTTPOnly,
                "secure": cookie.isSecure
            ] as [String: Any]
        }

        let payload = [
            "cookies": cookieData,
            "timestamp": Int(Date().timeIntervalSince1970)
        ] as [String: Any]

        makeAuthenticatedRequest(
            path: "/api/store-cookies",
            method: "POST",
            body: payload,
            completion: completion
        )
    }

    func sendMessage(_ message: String, completion: @escaping (Bool, Error?) -> Void) {
        guard authManager.hasValidOAuthToken() else {
            completion(false, NSError(domain: "APIError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No valid OAuth token"]))
            return
        }

        guard cookieManager.hasValidCookies() else {
            completion(false, NSError(domain: "APIError", code: -3, userInfo: [NSLocalizedDescriptionKey: "No valid cookies available"]))
            return
        }

        let payload = [
            "message": message,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]

        makeAuthenticatedRequest(
            path: "/api/send-message",
            method: "POST",
            body: payload,
            completion: completion
        )
    }

    // MARK: Feed

    func fetchFeed(limit: Int = 25, completion: @escaping (Result<[FeedPost], Error>) -> Void) {
        fetchMonitoringStatus { result in
            switch result {
            case .success(let status):
                let posts = Array(status.recentPosts.prefix(limit))
                completion(.success(posts))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchMonitoringStatus(completion: @escaping (Result<MonitoringStatus, Error>) -> Void) {
        performRequest(path: "/api/v1/users/monitoring/status", completion: completion)
    }

    func fetchTimeline(count: Int = 40, completion: @escaping (Result<TimelineFetchResponse, Error>) -> Void) {
        let items = [URLQueryItem(name: "count", value: String(count))]
        performRequest(path: "/api/v1/posts/fetch-timeline", method: "POST", queryItems: items, completion: completion)
    }

    // MARK: Posting Queue

    func fetchPostingJobs(status: String? = nil, completion: @escaping (Result<PostingJobListResponse, Error>) -> Void) {
        var items: [URLQueryItem] = []
        if let status {
            items.append(URLQueryItem(name: "status", value: status))
        }
        performRequest(path: "/api/v1/posting-jobs", queryItems: items, completion: completion)
    }

    // MARK: Draft Replies

    func fetchDraftReplies(status: String = "generated", completion: @escaping (Result<[DraftReply], Error>) -> Void) {
        let items = [URLQueryItem(name: "status", value: status)]
        performRequest(path: "/api/v1/replies", queryItems: items, completion: completion)
    }

    // MARK: User Management

    func fetchMonitoredUsers(limit: Int = 50, completion: @escaping (Result<[MonitoredUser], Error>) -> Void) {
        let items = [URLQueryItem(name: "limit", value: String(limit))]
        performRequest(path: "/api/v1/users/me/monitored", queryItems: items, completion: completion)
    }

    // MARK: Settings

    func fetchSettingsStatus(completion: @escaping (Result<SettingsStatus, Error>) -> Void) {
        performRequest(path: "/api/v1/settings/status", completion: completion)
    }

    // MARK: Health Check

    func checkAPIHealth(completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let url = buildURL(path: "/api/health") else {
            completion(false, nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Health check failed: \(error)")
                    completion(false, nil)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, nil)
                    return
                }

                let isHealthy = httpResponse.statusCode == 200

                var healthData: [String: Any]?
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    healthData = json
                }

                completion(isHealthy, healthData)
            }
        }.resume()
    }

    // MARK: Private Helpers

    private func performRequest<T: Decodable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let url = buildURL(path: path, queryItems: queryItems) else {
            completion(.failure(APIClientError.invalidURL))
            return
        }

        guard let token = authManager.getOAuthToken() else {
            completion(.failure(APIClientError.missingAuthToken))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

#if DEBUG
        print("🌐 [API] \(method) \(url.absoluteString)")
        let tokenPreview = token.prefix(6)
        print("   ↳ bearer token prefix: \(tokenPreview)… (length: \(token.count))")
        if let body,
           let bodyString = String(data: body, encoding: .utf8),
           !bodyString.isEmpty {
            print("   ↳ body: \(bodyString)")
        }
#endif

        session.dataTask(with: request) { [decoder] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
#if DEBUG
                    print("❌ [API] transport error: \(error.localizedDescription)")
#endif
                    completion(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
#if DEBUG
                    print("❌ [API] invalid response object")
#endif
                    completion(.failure(APIClientError.requestFailed("Invalid response")))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
#if DEBUG
                    if let data,
                       let raw = String(data: data, encoding: .utf8),
                       !raw.isEmpty {
                        print("⚠️ [API] \(httpResponse.statusCode) response body: \(raw)")
                    } else {
                        print("⚠️ [API] \(httpResponse.statusCode) no body")
                    }
#endif
                    completion(.failure(APIClientError.requestFailed(message)))
                    return
                }

                guard let data = data else {
#if DEBUG
                    print("⚠️ [API] empty response body")
#endif
                    completion(.failure(APIClientError.requestFailed("Empty response")))
                    return
                }

                do {
                    let result = try decoder.decode(T.self, from: data)
#if DEBUG
                    print("✅ [API] decoded \(T.self) successfully")
#endif
                    completion(.success(result))
                } catch {
#if DEBUG
                    if let raw = String(data: data, encoding: .utf8) {
                        print("❌ [API] decode error: \(error). Raw: \(raw)")
                    } else {
                        print("❌ [API] decode error: \(error)")
                    }
#endif
                    completion(.failure(APIClientError.decodingFailed(error)))
                }
            }
        }.resume()
    }

    private func makeAuthenticatedRequest(
        path: String,
        method: String,
        body: [String: Any]?,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard let url = buildURL(path: path) else {
            completion(false, NSError(domain: "APIError", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        guard let token = authManager.getOAuthToken() else {
            completion(false, NSError(domain: "APIError", code: -5, userInfo: [NSLocalizedDescriptionKey: "No authentication token"]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                completion(false, error)
                return
            }
        }

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, NSError(domain: "APIError", code: -6, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                    return
                }

                let isSuccess = (200...299).contains(httpResponse.statusCode)

                if !isSuccess {
                    var message = "Request failed with status \(httpResponse.statusCode)"

                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let detail = json["detail"] as? String {
                            message = detail
                        } else if let errorMessage = json["error"] as? String {
                            message = errorMessage
                        }
                    }

                    let error = NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
                    completion(false, error)
                } else {
                    completion(true, nil)
                }
            }
        }.resume()
    }

    private func buildURL(path: String, queryItems: [URLQueryItem] = []) -> URL? {
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.path = path
        components.percentEncodedQueryItems = queryItems.isEmpty ? nil : queryItems

        if let port = baseURL.port {
            components.port = port
        }

        return components.url
    }
    
    // MARK: - Bulk Operations
    
    func bulkGenerateReplies(postIds: [String], completion: @escaping (Result<BulkOperationResponse, Error>) -> Void) {
        let formData = ["post_ids": postIds.joined(separator: ",")]
        performFormRequest(path: "/api/v1/replies/bulk-generate-and-queue", method: "POST", formData: formData, completion: completion)
    }
    
    func bulkLikeTweets(tweetIds: [String], completion: @escaping (Result<BulkOperationResponse, Error>) -> Void) {
        let formData = ["tweet_ids": tweetIds.joined(separator: ",")]
        performFormRequest(path: "/api/v1/replies/twikit/like-tweets-bulk", method: "POST", formData: formData, completion: completion)
    }
    
    private func performFormRequest<T: Decodable>(
        path: String,
        method: String = "GET",
        formData: [String: String],
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let url = buildURL(path: path) else {
            completion(.failure(APIClientError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add OAuth token if available
        if let token = authManager.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Build form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        for (key, value) in formData {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(APIClientError.requestFailed("No data received")))
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 Response status: \(httpResponse.statusCode) for \(path)")
                    
                    if httpResponse.statusCode >= 400 {
                        if let errorString = String(data: data, encoding: .utf8) {
                            print("❌ Error response: \(errorString)")
                            completion(.failure(APIClientError.requestFailed("HTTP \(httpResponse.statusCode): \(errorString)")))
                        } else {
                            completion(.failure(APIClientError.requestFailed("HTTP \(httpResponse.statusCode)")))
                        }
                        return
                    }
                }

                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let decoded = try decoder.decode(T.self, from: data)
                    completion(.success(decoded))
                } catch {
                    print("❌ Decoding error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📄 Response JSON: \(jsonString)")
                    }
                    completion(.failure(APIClientError.decodingFailed(error)))
                }
            }
        }

        task.resume()
    }
}

// MARK: - Diagnostics

extension APIClient {
    func testConnectivity(completion: @escaping (Bool, TimeInterval) -> Void) {
        let startTime = CFAbsoluteTimeGetCurrent()

        checkAPIHealth { isHealthy, _ in
            let responseTime = CFAbsoluteTimeGetCurrent() - startTime
            completion(isHealthy, responseTime)
        }
    }

    func validateConfiguration() -> [String] {
        var issues: [String] = []

        if !authManager.hasValidOAuthToken() {
            issues.append("🔑 No OAuth token available - complete authentication first")
        }

        if !cookieManager.hasValidCookies() {
            issues.append("🍪 No valid cookies available - authenticate with X.com")
        }

        return issues
    }
}

private extension KeyedDecodingContainer {
    func decodeDateIfPresent(forKey key: Key) -> Date? {
        guard let string = try? decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        return DateParsing.parse(string)
    }
}