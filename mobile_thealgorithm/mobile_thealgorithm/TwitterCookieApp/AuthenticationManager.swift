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
    private let twitterLoginURL = URL(string: "https://x.com/login")!
    private let userAgentString = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
    
    // PKCE (Proof Key for Code Exchange) properties
    private var codeVerifier: String?
    private var codeChallenge: String?
    
    // Universal Link handling
    private var universalLinkConversions: [(url: String, timestamp: Date)] = []
    private let universalLinkConversionWindow: TimeInterval = 1.0 // 1 second window
    private let maxUniversalLinkConversions = 2 // Max conversions before blocking
    private let maxRedirectUniversalLinkConversions = 4 // Higher threshold for redirect.x.com before blocking
    private var redirectUniversalLinkHistory: [String: Date] = [:]
    private let redirectUniversalLinkSuppressDuration: TimeInterval = 3.0
    
    // MARK: - Public Methods
    
    func hasValidOAuthToken() -> Bool {
        return getOAuthToken() != nil
    }
    
    func authenticateWithOAuth(completion: @escaping (Bool, Error?) -> Void) {
        self.oauthCompletion = completion
        
        // Clear any old PKCE verifier from previous attempts
        UserDefaults.standard.removeObject(forKey: "pkce_code_verifier")
        self.codeVerifier = nil
        self.codeChallenge = nil
        print("🧹 Cleared old PKCE codes, starting fresh")
        
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
        
        // Reset Universal Link conversion tracking for fresh session
        universalLinkConversions.removeAll()
        redirectUniversalLinkHistory.removeAll()
        
        print("🐦 Starting X.com authentication...")
        
        let webView = createTwitterWebView()
        self.twitterWebView = webView
        
        let navController = UINavigationController(rootViewController: createWebViewController(with: webView, title: "Authenticate with X.com"))
        viewController.present(navController, animated: true)
        
        // Load X.com login page
        print("📍 Loading X.com URL: \(twitterLoginURL.absoluteString)")
        loadTwitterLoginPage(in: webView)
        print("✅ WebView load initiated")
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
        
        // Store verifier for token exchange (persist to UserDefaults in case app is suspended)
        self.codeVerifier = verifier
        self.codeChallenge = challenge
        UserDefaults.standard.set(verifier, forKey: "pkce_code_verifier")
        print("💾 Saved PKCE verifier to UserDefaults")
        print("   Verifier (first 20): \(verifier.prefix(20))...")
        print("   Challenge (first 20): \(challenge.prefix(20))...")
        
        var components = URLComponents(string: oauthURL)
        let state = UUID().uuidString
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "read,write"), // Backend expects comma-separated
            URLQueryItem(name: "state", value: state), // CSRF protection
            URLQueryItem(name: "code_challenge", value: challenge), // PKCE
            URLQueryItem(name: "code_challenge_method", value: "S256") // SHA256
        ]
        
        if let url = components?.url {
            print("🔗 OAuth URL created:")
            print("   Full URL: \(url.absoluteString)")
            print("   Challenge being sent: \(challenge)")
        }
        
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
        config.websiteDataStore = WKWebsiteDataStore.default() // Use default to allow cookies

        // Enable JavaScript
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        let userContentController = WKUserContentController()
        let blockUniversalLinkScript = """
        (function() {
            const blockedPrefixes = ["x-safari-https://redirect.x.com/"];
            const shouldBlock = function(url) {
                if (!url) {
                    return false;
                }
                try {
                    const href = (typeof url === 'string' ? url : (url.href || '')).toLowerCase();
                    return blockedPrefixes.some(prefix => href.startsWith(prefix));
                } catch (error) {
                    return false;
                }
            };

            const locationProto = window.Location && window.Location.prototype;
            if (locationProto && !locationProto.__companionUniversalLinkPatched) {
                const originalAssign = locationProto.assign;
                const originalReplace = locationProto.replace;
                const hrefDescriptor = Object.getOwnPropertyDescriptor(locationProto, 'href');

                const wrapNavigation = fn => {
                    if (!fn) {
                        return undefined;
                    }
                    return function(url) {
                        if (shouldBlock(url)) {
                            return;
                        }
                        return fn.apply(this, arguments);
                    };
                };

                if (originalAssign) {
                    locationProto.assign = wrapNavigation(originalAssign);
                }

                if (originalReplace) {
                    locationProto.replace = wrapNavigation(originalReplace);
                }

                if (hrefDescriptor && hrefDescriptor.set) {
                    const originalSetter = hrefDescriptor.set;
                    Object.defineProperty(locationProto, 'href', {
                        configurable: hrefDescriptor.configurable,
                        enumerable: hrefDescriptor.enumerable,
                        get: hrefDescriptor.get,
                        set: function(value) {
                            if (shouldBlock(value)) {
                                return value;
                            }
                            return originalSetter.call(this, value);
                        }
                    });
                }

                const originalOpen = window.open;
                if (originalOpen) {
                    window.open = function(url) {
                        if (shouldBlock(url)) {
                            return null;
                        }
                        return originalOpen.apply(this, arguments);
                    };
                }

                Object.defineProperty(locationProto, '__companionUniversalLinkPatched', {
                    value: true,
                    configurable: false,
                    enumerable: false,
                    writable: false
                });
            }
        })();
        """

        let universalLinkBlocker = WKUserScript(source: blockUniversalLinkScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContentController.addUserScript(universalLinkBlocker)
        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = userAgentString
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        print("🌐 Created WebView with configuration")
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

    private func loadTwitterLoginPage(in webView: WKWebView, url: URL? = nil) {
        let targetURL = url ?? twitterLoginURL
        var request = URLRequest(url: targetURL)
        request.setValue(userAgentString, forHTTPHeaderField: "User-Agent")
        webView.load(request)
    }
    
    @objc private func handleOAuthCallback(_ notification: Notification) {
        print("🔔 OAuth callback received!")
        
        guard let url = notification.object as? URL else {
            print("❌ No URL in notification")
            oauthCompletion?(false, NSError(domain: "AuthError", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid callback URL"]))
            return
        }
        
        print("📍 Callback URL: \(url.absoluteString)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("❌ Failed to parse URL components")
            oauthCompletion?(false, NSError(domain: "AuthError", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid callback URL"]))
            return
        }
        
        print("🔍 Query items: \(queryItems.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: ", "))")
        
        // Extract authorization code
        if let code = queryItems.first(where: { $0.name == "code" })?.value {
            print("✅ Authorization code found: \(code.prefix(20))...")
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
            print("❌ OAuth error in callback: \(error)")
            oauthCompletion?(false, NSError(domain: "AuthError", code: -5, userInfo: [NSLocalizedDescriptionKey: "OAuth error: \(error)"]))
        } else {
            print("❌ No authorization code in callback URL")
            oauthCompletion?(false, NSError(domain: "AuthError", code: -6, userInfo: [NSLocalizedDescriptionKey: "No authorization code received"]))
        }
        
        NotificationCenter.default.removeObserver(self, name: .authCallbackReceived, object: nil)
    }
    
    private func exchangeCodeForToken(_ code: String, completion: @escaping (String?, Error?) -> Void) {
        // Try to get verifier from memory first, then UserDefaults
        var verifier = codeVerifier
        if verifier == nil {
            verifier = UserDefaults.standard.string(forKey: "pkce_code_verifier")
            print("📂 Retrieved PKCE verifier from UserDefaults")
        }
        
        guard let verifier = verifier else {
            print("❌ Missing PKCE code verifier (checked memory and UserDefaults)")
            completion(nil, NSError(domain: "AuthError", code: -10, userInfo: [NSLocalizedDescriptionKey: "Missing PKCE code verifier"]))
            return
        }
        
        print("🔄 Exchanging authorization code for token...")
        print("   Token URL: \(tokenURL)")
        print("   Code: \(code.prefix(20))...")
        print("   Using verifier (first 20): \(verifier.prefix(20))...")
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // 30 second timeout
        
        // Include code_verifier for PKCE verification
        let body = "grant_type=authorization_code&client_id=\(clientID)&code=\(code)&redirect_uri=\(redirectURI)&code_verifier=\(verifier)"
        request.httpBody = body.data(using: .utf8)
        print("📤 Request body: grant_type=authorization_code&client_id=\(clientID)&code=\(code.prefix(20))...&redirect_uri=\(redirectURI)&code_verifier=\(verifier.prefix(20))...")
        
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
            // Clear the stored verifier after successful exchange
            UserDefaults.standard.removeObject(forKey: "pkce_code_verifier")
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
        print("✅ WebView finished loading: \(webView.url?.absoluteString ?? "unknown")")
        // Check if this is the Twitter authentication WebView
        if webView == twitterWebView {
            checkTwitterAuthenticationStatus(webView)
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView navigation failed: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        // Error code 102 is WKNavigationErrorFrameLoadInterrupted, which is expected when converting Universal Links
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 {
            print("⚠️ Frame load interrupted (expected when converting Universal Links)")
        } else {
            print("❌ WebView provisional navigation failed: \(error.localizedDescription)")
            if let url = webView.url {
                print("   URL: \(url.absoluteString)")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("🔄 WebView started loading: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        if let url = webView.url {
            print("🔄 Server redirect detected: \(url.absoluteString)")
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        let scheme = url.scheme ?? "unknown"
        let navigationType = navigationAction.navigationType.rawValue
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        
        print("🔍 Navigation policy check for: \(url.absoluteString)")
        print("   Scheme: \(scheme)")
        print("   Navigation type: \(navigationType)")
        print("   Is main frame: \(isMainFrame)")
        
        // Handle OAuth redirect URLs
        if url.scheme == "thealgorithm" {
            decisionHandler(.cancel)
            handleOAuthCallback(Notification(name: .authCallbackReceived, object: url))
            return
        }
        
        // Handle Universal Links (x-safari-https:// scheme)
        if url.scheme == "x-safari-https" {
            // Clean up old conversion records outside the time window
            let now = Date()
            universalLinkConversions = universalLinkConversions.filter {
                now.timeIntervalSince($0.timestamp) < universalLinkConversionWindow
            }

            // Convert Universal Link to regular HTTPS URL
            let httpsURLString = url.absoluteString.replacingOccurrences(of: "x-safari-https://", with: "https://")
            let isRedirectDomain = url.host?.contains("redirect.x.com") == true

            if isRedirectDomain {
                redirectUniversalLinkHistory = redirectUniversalLinkHistory.filter {
                    now.timeIntervalSince($0.value) < redirectUniversalLinkSuppressDuration
                }

                if let lastConversion = redirectUniversalLinkHistory[httpsURLString] {
                    let delta = now.timeIntervalSince(lastConversion)
                    print("⏹️ Ignoring repeated redirect.x.com Universal Link (converted \(String(format: "%.2f", delta))s ago)")
                    print("   URL: \(url.absoluteString)")
                    decisionHandler(.cancel)

                    DispatchQueue.main.async { [weak self] in
                        self?.loadTwitterLoginPage(in: webView)
                    }
                    return
                }
            }

            let conversionLimit = isRedirectDomain ? maxRedirectUniversalLinkConversions : maxUniversalLinkConversions

            // Count recent conversions of this specific URL
            let recentConversions = universalLinkConversions.filter { $0.url == httpsURLString }

            if recentConversions.count >= conversionLimit {
                let timeSpan = recentConversions.isEmpty ? 0.0 : now.timeIntervalSince(recentConversions.first!.timestamp)
                print("🛑 Blocking Universal Link - detected loop")
                print("   URL: \(url.absoluteString)")
                print("   Converted \(recentConversions.count) times in \(String(format: "%.2f", timeSpan))s")
                decisionHandler(.cancel)
                return
            }

            // Record this conversion
            universalLinkConversions.append((url: httpsURLString, timestamp: now))
            if isRedirectDomain {
                redirectUniversalLinkHistory[httpsURLString] = now
            }

            // Convert and load the HTTPS URL
            if let httpsURL = URL(string: httpsURLString) {
                print("🔄 Converting Universal Link to HTTPS")
                if isRedirectDomain {
                    print("   Detected redirect.x.com Universal Link")
                }
                print("   From: \(url.absoluteString)")
                print("   To: \(httpsURLString)")

                decisionHandler(.cancel)

                // Load the converted URL with proper headers
                DispatchQueue.main.async { [weak self] in
                    self?.loadTwitterLoginPage(in: webView, url: httpsURL)
                }
                return
            }
        }
        
        // Allow web navigation for HTTPS/HTTP schemes
        if scheme == "https" || scheme == "http" {
            print("✅ Allowing web navigation scheme: \(scheme)")
        }
        
        // Allow all other navigation
        decisionHandler(.allow)
    }
    
    private func checkTwitterAuthenticationStatus(_ webView: WKWebView) {
        // Always check for valid cookies when page finishes loading
        // This works for both:
        // 1. Users who just logged in
        // 2. Users who are already logged in
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            // Check if we have valid auth cookies
            let hasAuthToken = cookies.contains { cookie in
                cookie.name == "auth_token" && 
                (cookie.domain.contains("x.com") || cookie.domain.contains("twitter.com"))
            }
            
            if hasAuthToken {
                print("✅ Found existing auth_token cookie, extracting all cookies...")
                self?.extractTwitterCookies(from: webView)
            } else {
                // No auth token yet, check if we're on a page that indicates successful login
                webView.evaluateJavaScript("document.location.href") { result, error in
                    guard let urlString = result as? String,
                          let url = URL(string: urlString) else { return }
                    
                    // Check for successful login indicators
                    if url.path.contains("home") || url.path.contains("timeline") || urlString.contains("x.com/home") {
                        print("✅ On home page, attempting cookie extraction...")
                        self?.extractTwitterCookies(from: webView)
                    } else {
                        print("ℹ️ On page: \(urlString) - waiting for login...")
                    }
                }
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
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.presentingViewController?.dismiss(animated: true) { [weak self] in
                    guard let self = self else { return }
                    if !twitterCookies.isEmpty {
                        self.twitterCompletion?(twitterCookies, nil)
                    } else {
                        self.twitterCompletion?(nil, NSError(domain: "AuthError", code: -9, userInfo: [NSLocalizedDescriptionKey: "No authentication cookies found"]))
                    }
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