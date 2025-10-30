import Foundation

class APIClient {
    
    // MARK: - Configuration
    // Replace with your actual backend URL
    private let baseURL = "https://thealgorithm.live/api"
    
    private let session: URLSession
    private let authManager = AuthenticationManager()
    private let cookieManager = CookieManager()
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Cookie Management
    
    func storeCookies(_ cookies: [HTTPCookie], completion: @escaping (Bool, Error?) -> Void) {
        guard let token = authManager.getOAuthToken() else {
            completion(false, NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No OAuth token available"]))
            return
        }
        
        let cookieData = cookies.map { cookie in
            return [
                "name": cookie.name,
                "value": cookie.value,
                "domain": cookie.domain,
                "path": cookie.path,
                "expires": cookie.expiresDate?.timeIntervalSince1970 ?? 0,
                "httpOnly": cookie.isHTTPOnly,
                "secure": cookie.isSecure
            ] as [String: Any]
        }
        
        let payload = [
            "cookies": cookieData,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        makeAuthenticatedRequest(
            endpoint: "/store-cookies",
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
            endpoint: "/send-message",
            method: "POST",
            body: payload,
            completion: completion
        )
    }
    
    // MARK: - User Management
    
    func getUserProfile(completion: @escaping ([String: Any]?, Error?) -> Void) {
        makeAuthenticatedRequest(
            endpoint: "/profile",
            method: "GET",
            body: nil
        ) { success, error in
            if success {
                // In a real implementation, you'd parse the response data here
                let mockProfile = [
                    "username": "user123",
                    "email": "user@example.com",
                    "created_at": Date().timeIntervalSince1970
                ]
                completion(mockProfile, nil)
            } else {
                completion(nil, error)
            }
        }
    }
    
    func updateUserSettings(_ settings: [String: Any], completion: @escaping (Bool, Error?) -> Void) {
        makeAuthenticatedRequest(
            endpoint: "/settings",
            method: "PUT",
            body: settings,
            completion: completion
        )
    }
    
    // MARK: - Message History
    
    func getMessageHistory(completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        makeAuthenticatedRequest(
            endpoint: "/messages/history",
            method: "GET",
            body: nil
        ) { success, error in
            if success {
                // Mock message history - replace with actual API response parsing
                let mockHistory = [
                    [
                        "id": "1",
                        "message": "Hello, world!",
                        "timestamp": Date().timeIntervalSince1970 - 3600,
                        "status": "sent"
                    ],
                    [
                        "id": "2",
                        "message": "Another test message",
                        "timestamp": Date().timeIntervalSince1970 - 1800,
                        "status": "sent"
                    ]
                ]
                completion(mockHistory, nil)
            } else {
                completion(nil, error)
            }
        }
    }
    
    // MARK: - Health Check
    
    func checkAPIHealth(completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else {
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
    
    // MARK: - Private Helper Methods
    
    private func makeAuthenticatedRequest(
        endpoint: String,
        method: String,
        body: [String: Any]?,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
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
        
        // Add body for POST/PUT requests
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                completion(false, error)
                return
            }
        }
        
        // Log request details (remove in production)
        print("🌐 API Request: \(method) \(endpoint)")
        if let body = body {
            print("📦 Body: \(body)")
        }
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ API Error: \(error)")
                    completion(false, error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, NSError(domain: "APIError", code: -6, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                    return
                }
                
                print("📨 API Response: \(httpResponse.statusCode)")
                
                let isSuccess = 200...299 ~= httpResponse.statusCode
                
                if !isSuccess {
                    var errorMessage = "Request failed with status \(httpResponse.statusCode)"
                    
                    // Try to parse error message from response
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["error"] as? String {
                        errorMessage = message
                    }
                    
                    let error = NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    completion(false, error)
                } else {
                    completion(true, nil)
                }
            }
        }.resume()
    }
}

// MARK: - API Response Models

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
    let timestamp: TimeInterval
}

struct MessageResponse: Codable {
    let id: String
    let status: String
    let timestamp: TimeInterval
}

struct UserProfile: Codable {
    let id: String
    let username: String
    let email: String
    let createdAt: TimeInterval
    let settings: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id, username, email, settings
        case createdAt = "created_at"
    }
}

struct MessageHistory: Codable {
    let messages: [MessageItem]
    let totalCount: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case messages
        case totalCount = "total_count"
        case hasMore = "has_more"
    }
}

struct MessageItem: Codable {
    let id: String
    let message: String
    let timestamp: TimeInterval
    let status: String
    let recipientId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, message, timestamp, status
        case recipientId = "recipient_id"
    }
}

// MARK: - Network Monitoring

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
        
        if baseURL.isEmpty || baseURL == "https://thealgorithm.live/api" {
            issues.append("⚠️ Base URL not configured - update APIClient.baseURL")
        }
        
        if !authManager.hasValidOAuthToken() {
            issues.append("🔑 No OAuth token available - complete authentication first")
        }
        
        if !cookieManager.hasValidCookies() {
            issues.append("🍪 No valid cookies available - authenticate with X.com")
        }
        
        return issues
    }
}