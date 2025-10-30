import UIKit
import WebKit
import Security
import CommonCrypto

class AuthenticationManager: NSObject {
    
    // MARK: - Configuration
    // Replace these with your actual OAuth endpoints
    private let oauthURL = "https://thealgorithm.live/oauth/authorize"
    private let tokenURL = "https://thealgorithm.live/oauth/token"
    private let redirectURI = "thealgorithm://oauth/callback"
    private let clientID = "ios_app_081b7e3ab09f49b2" // Replace with your actual client ID from register_ios_oauth_client.py
    
    // MARK: - Properties
    private var oauthWebView: WKWebView?
    private var twitterWebView: WKWebView?
    private var oauthCompletion: ((Bool, Error?) -> Void)?
    private var twitterCompletion: (([HTTPCookie]?, Error?) -> Void)?
    private var presentingViewController: UIViewController?
    
    // PKCE (Proof Key for Code Exchange) properties
    private var codeVerifier: String?
    private var codeChallenge: String?
    
    // MARK: - Public Methods
    
    func hasValidOAuthToken() -> Bool {
        return getOAuthToken() != nil
    }
    
    func authenticateWithOAuth(completion: @escaping (Bool, Error?) -> Void) {
        self.oauthCompletion = completion
        
        // Listen for OAuth callback
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOAuthCallback(_:)),
            name: .authCallbackReceived,
            object: nil
        )
        
        // Create OAuth URL with parameters
        guard let url = createOAuthURL() else {
            completion(false, NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid OAuth URL"]))
            return
        }
        
        // Open OAuth URL in Safari or in-app browser
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    completion(false, NSError(domain: "AuthError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to open OAuth URL"]))
                }
            }
        } else {
            // Fallback to in-app WebView if Safari isn't available
            presentOAuthWebView(url: url)
        }
    }
    
    func authenticateWithTwitter(from viewController: UIViewController, completion: @escaping ([HTTPCookie]?, Error?) -> Void) {
        self.twitterCompletion = completion
        self.presentingViewController = viewController
        
        let webView = createTwitterWebView()
        self.twitterWebView = webView
        
        let navController = UINavigationController(rootViewController: createWebViewController(with: webView, title: "Authenticate with X.com"))
        viewController.present(navController, animated: true)
        
        // Load X.com login page
        let loginURL = URL(string: "https://x.com/login")!
        webView.load(URLRequest(url: loginURL))
    }
    
    func getOAuthToken() -> String? {
        return KeychainHelper.read(service: "TheAlgorithm", account: "oauth_token")
    }
    
    // MARK: - Private Methods
    
    private func createOAuthURL() -> URL? {
        // Generate PKCE codes
        guard let verifier = generateCodeVerifier(),
              let challenge = generateCodeChallenge(from: verifier) else {
            print("❌ Failed to generate PKCE codes")
            return nil
        }
        
        // Store verifier for token exchange
        self.codeVerifier = verifier
        self.codeChallenge = challenge
        
        var components = URLComponents(string: oauthURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "read,write"), // Backend expects comma-separated
            URLQueryItem(name: "state", value: UUID().uuidString), // CSRF protection
            URLQueryItem(name: "code_challenge", value: challenge), // PKCE
            URLQueryItem(name: "code_challenge_method", value: "S256") // SHA256
        ]
        return components?.url
    }
    
    private func presentOAuthWebView(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let topViewController = windowScene.windows.first?.rootViewController else {
            oauthCompletion?(false, NSError(domain: "AuthError", code: -3, userInfo: [NSLocalizedDescriptionKey: "No presenting view controller"]))
            return
        }
        
        let webView = WKWebView()
        webView.navigationDelegate = self
        self.oauthWebView = webView
        
        let webViewController = createWebViewController(with: webView, title: "Authenticate")
        let navController = UINavigationController(rootViewController: webViewController)
        
        topViewController.present(navController, animated: true)
        webView.load(URLRequest(url: url))
    }
    
    private func createTwitterWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent() // Fresh session
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        return webView
    }
    
    private func createWebViewController(with webView: WKWebView, title: String) -> UIViewController {
        let viewController = UIViewController()
        viewController.title = title
        viewController.view.backgroundColor = .systemBackground
        
        // Add web view
        webView.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
        
        // Add cancel button
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelAuthentication)
        )
        
        return viewController
    }
    
    @objc private func handleOAuthCallback(_ notification: Notification) {
        guard let url = notification.object as? URL,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            oauthCompletion?(false, NSError(domain: "AuthError", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid callback URL"]))
            return
        }
        
        // Extract authorization code
        if let code = queryItems.first(where: { $0.name == "code" })?.value {
            // Exchange code for token (you'll need to implement this based on your OAuth provider)
            exchangeCodeForToken(code) { [weak self] token, error in
                if let token = token {
                    // Store token securely
                    KeychainHelper.save(token, service: "TheAlgorithm", account: "oauth_token")
                    self?.oauthCompletion?(true, nil)
                } else {
                    self?.oauthCompletion?(false, error)
                }
            }
        } else if let error = queryItems.first(where: { $0.name == "error" })?.value {
            oauthCompletion?(false, NSError(domain: "AuthError", code: -5, userInfo: [NSLocalizedDescriptionKey: "OAuth error: \(error)"]))
        } else {
            oauthCompletion?(false, NSError(domain: "AuthError", code: -6, userInfo: [NSLocalizedDescriptionKey: "No authorization code received"]))
        }
        
        NotificationCenter.default.removeObserver(self, name: .authCallbackReceived, object: nil)
    }
    
    private func exchangeCodeForToken(_ code: String, completion: @escaping (String?, Error?) -> Void) {
        guard let verifier = codeVerifier else {
            print("❌ Missing PKCE code verifier")
            completion(nil, NSError(domain: "AuthError", code: -10, userInfo: [NSLocalizedDescriptionKey: "Missing PKCE code verifier"]))
            return
        }
        
        print("🔄 Exchanging authorization code for token...")
        print("   Token URL: \(tokenURL)")
        print("   Code: \(code.prefix(20))...")
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // 30 second timeout
        
        // Include code_verifier for PKCE verification
        let body = "grant_type=authorization_code&client_id=\(clientID)&code=\(code)&redirect_uri=\(redirectURI)&code_verifier=\(verifier)"
        request.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error during token exchange: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📨 Token exchange response status: \(httpResponse.statusCode)")
            }
            
            if let data = data {
                print("📦 Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String else {
                print("❌ Failed to parse token response")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("   Response body: \(responseString)")
                }
                completion(nil, NSError(domain: "AuthError", code: -7, userInfo: [NSLocalizedDescriptionKey: "Failed to parse token response"]))
                return
            }
            
            print("✅ Successfully obtained access token")
            completion(token, nil)
        }.resume()
    }
    
    @objc private func cancelAuthentication() {
        presentingViewController?.dismiss(animated: true)
        twitterCompletion?(nil, NSError(domain: "AuthError", code: -8, userInfo: [NSLocalizedDescriptionKey: "Authentication cancelled"]))
        oauthCompletion?(false, NSError(domain: "AuthError", code: -8, userInfo: [NSLocalizedDescriptionKey: "Authentication cancelled"]))
    }
    
    // MARK: - PKCE Helper Methods
    
    /// Generates a random code verifier for PKCE
    /// Returns a cryptographically random string of 43-128 characters
    private func generateCodeVerifier() -> String? {
        var buffer = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        
        guard result == errSecSuccess else {
            print("❌ Failed to generate random bytes for code verifier")
            return nil
        }
        
        // Convert to base64url encoding (RFC 7636)
        let data = Data(buffer)
        let base64 = data.base64EncodedString()
        let base64url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return base64url
    }
    
    /// Generates a code challenge from the code verifier using SHA256
    /// As per RFC 7636, the challenge is BASE64URL(SHA256(ASCII(code_verifier)))
    private func generateCodeChallenge(from verifier: String) -> String? {
        guard let data = verifier.data(using: .ascii) else {
            print("❌ Failed to convert verifier to ASCII data")
            return nil
        }
        
        // Calculate SHA256 hash
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        
        // Convert to base64url encoding
        let hashData = Data(hash)
        let base64 = hashData.base64EncodedString()
        let base64url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return base64url
    }
}

// MARK: - WKNavigationDelegate

extension AuthenticationManager: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Check if this is the Twitter authentication WebView
        if webView == twitterWebView {
            checkTwitterAuthenticationStatus(webView)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        // Handle OAuth redirect URLs
        if let url = navigationAction.request.url,
           url.scheme == "thealgorithm" {
            decisionHandler(.cancel)
            handleOAuthCallback(Notification(name: .authCallbackReceived, object: url))
            return
        }
        
        decisionHandler(.allow)
    }
    
    private func checkTwitterAuthenticationStatus(_ webView: WKWebView) {
        // Check if we're on a page that indicates successful login
        webView.evaluateJavaScript("document.location.href") { [weak self] result, error in
            guard let urlString = result as? String,
                  let url = URL(string: urlString) else { return }
            
            // Check for successful login indicators
            if url.path.contains("home") || url.path.contains("timeline") || urlString.contains("x.com/home") {
                self?.extractTwitterCookies(from: webView)
            }
        }
    }
    
    private func extractTwitterCookies(from webView: WKWebView) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            // Filter for Twitter/X.com cookies
            let twitterCookies = cookies.filter { cookie in
                let domain = cookie.domain.lowercased()
                return (domain.contains("x.com") || domain.contains("twitter.com")) &&
                       ["auth_token", "ct0", "auth_multi", "twid", "kdt", "remember_checked_on"].contains(cookie.name)
            }
            
            DispatchQueue.main.async {
                self?.presentingViewController?.dismiss(animated: true)
                
                if !twitterCookies.isEmpty {
                    self?.twitterCompletion?(twitterCookies, nil)
                } else {
                    self?.twitterCompletion?(nil, NSError(domain: "AuthError", code: -9, userInfo: [NSLocalizedDescriptionKey: "No authentication cookies found"]))
                }
            }
        }
    }
}

// MARK: - Keychain Helper

class KeychainHelper {
    
    static func save(_ data: String, service: String, account: String) {
        let data = data.data(using: .utf8)!
        
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func read(service: String, account: String) -> String? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == noErr {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        
        return nil
    }
    
    static func delete(service: String, account: String) {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary)
    }
}