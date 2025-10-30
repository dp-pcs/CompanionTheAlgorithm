# The Algorithm - iOS App

An iOS application that integrates with [thealgorithm.live](https://thealgorithm.live) to provide native mobile access to your platform's features with dual authentication flow.

## 🏗️ Architecture Overview

This app provides seamless integration with thealgorithm.live by implementing a dual authentication flow:

1. **OAuth Authentication** → Authenticate with thealgorithm.live
2. **Cookie Extraction** → Authenticate with X.com and extract session cookies
3. **Backend Integration** → Send cookies to your backend for API usage

## 📱 Features

- ✅ **Dual Authentication Flow** - OAuth + X.com cookie extraction
- ✅ **Secure Cookie Storage** - Uses iOS Keychain for secure storage
- ✅ **WebView Integration** - Native in-app authentication experience
- ✅ **Backend API Client** - Ready-to-use API client for thealgorithm.live
- ✅ **Cookie Validation** - Validates essential cookies are present
- ✅ **Error Handling** - Comprehensive error handling and user feedback
- ✅ **Modern UI** - Clean, intuitive interface with progress indicators

## 🚀 Quick Start

### 1. Configuration

Update the configuration constants in the following files:

**AuthenticationManager.swift:**
```swift
private let oauthURL = "https://thealgorithm.live/oauth/authorize"
private let clientID = "your_client_id"
```

**APIClient.swift:**
```swift
private let baseURL = "https://thealgorithm.live/api"
```

**Info.plist:**
```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>thealgorithm</string>  <!-- Your custom URL scheme -->
</array>
```

### 2. Backend Integration

Your thealgorithm.live backend should implement these endpoints:

```python
# Store cookies from iOS app
@app.route('/api/store-cookies', methods=['POST'])
def store_cookies():
    user_id = get_current_user_id()
    cookies = request.json['cookies']
    store_user_cookies(user_id, cookies)
    return {"status": "success"}

# Send message using stored cookies
@app.route('/api/send-message', methods=['POST'])
def send_message():
    user_id = get_current_user_id()
    cookies = get_user_cookies(user_id)
    
    # Use your API with stored cookies
    api_client = YourAPIClient()
    api_client.set_cookies(cookies)
    api_client.send_message(request.json['message'])
    return {"status": "sent"}
```

### 3. Usage Flow

1. **Launch App** → User sees authentication options
2. **OAuth Login** → User authenticates with thealgorithm.live  
3. **X.com Login** → User authenticates with X.com in WebView
4. **Auto-Extract** → App automatically extracts and stores cookies
5. **Send Messages** → User can now send messages through your backend

## 🔧 Technical Implementation

### Core Components

**AuthenticationManager**
- Handles OAuth flow with thealgorithm.live
- Manages X.com WebView authentication  
- Extracts HTTP cookies using `WKWebView.httpCookieStore`
- Stores tokens securely in iOS Keychain

**CookieManager**
- Validates essential Twitter cookies (`auth_token`, `ct0`, etc.)
- Provides secure storage/retrieval using Keychain
- Handles cookie expiration checking
- Converts cookies to network-friendly formats

**APIClient**
- Communicates with thealgorithm.live backend API
- Sends extracted cookies to your server
- Handles authenticated API requests
- Provides error handling and retry logic

### Cookie Extraction Process

```swift
// Extract cookies after successful X.com login
func extractTwitterCookies(from webView: WKWebView) {
    webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
        let twitterCookies = cookies.filter { cookie in
            let domain = cookie.domain.lowercased()
            return (domain.contains("x.com") || domain.contains("twitter.com")) &&
                   ["auth_token", "ct0", "auth_multi", "twid"].contains(cookie.name)
        }
        
        // Store cookies securely and send to backend
        self.cookieManager.storeCookies(twitterCookies)
        self.apiClient.storeCookies(twitterCookies)
    }
}
```

## 🔐 Security Features

- **Keychain Storage** - All sensitive data stored in iOS Keychain
- **Token Validation** - Validates OAuth tokens and cookie expiration
- **Secure Transport** - HTTPS-only API communication
- **CSRF Protection** - State parameter in OAuth flow
- **Domain Validation** - Ensures cookies are from correct domains

## 📋 Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.0+
- thealgorithm.live backend with OAuth support

## 🔄 Backend Requirements

Your thealgorithm.live backend needs to support:

1. **OAuth Flow** - Standard OAuth 2.0 authorization code flow
2. **Cookie Storage** - Endpoint to receive and store cookies from iOS
3. **Message API** - Endpoint that uses stored cookies
4. **Token Management** - Validate OAuth tokens in API requests

Example backend structure:
```
/oauth/authorize     → OAuth authorization endpoint
/oauth/token        → Token exchange endpoint  
/api/store-cookies  → Store cookies from iOS app
/api/send-message   → Send message using stored cookies
/api/profile        → Get user profile
/api/health         → Health check endpoint
```

## 🐛 Troubleshooting

**Common Issues:**

1. **OAuth Redirect Not Working**
   - Verify URL scheme is registered in Info.plist
   - Check redirect URI matches exactly in OAuth provider

2. **Cookies Not Extracted**
   - Ensure user completes X.com login (reaches timeline/home)
   - Check network connectivity during authentication
   - Verify WebView has access to x.com cookies

3. **API Calls Failing**
   - Update `baseURL` in APIClient.swift
   - Verify OAuth token is valid
   - Check backend endpoints are accessible

4. **Keychain Access Issues**
   - Ensure app has correct entitlements
   - Check device has passcode enabled
   - Verify app signing is correct

## 📱 Testing

Test the complete flow:

1. ✅ OAuth authentication redirects correctly
2. ✅ X.com WebView loads and accepts login
3. ✅ Cookies are extracted after successful login
4. ✅ Cookies are stored securely in Keychain
5. ✅ Backend receives cookies via API
6. ✅ Message sending works through backend
7. ✅ App handles errors gracefully

## 🚀 Deployment

1. **Update Configuration** - Set production URLs and credentials
2. **Test OAuth Flow** - Verify with production OAuth provider
3. **Backend Deployment** - Deploy backend with cookie endpoints  
4. **App Store Review** - Ensure compliance with App Store guidelines
5. **Monitor Usage** - Track authentication success rates

## 🤝 Contributing

This is a complete, production-ready implementation. Key areas for enhancement:

- Multiple account support
- Automatic cookie refresh
- Enhanced error recovery
- Background cookie validation
- Analytics integration

## 📄 License

MIT License - Use this code freely in your projects.

---

**Ready to build and deploy!** This complete iOS app integrates seamlessly with thealgorithm.live to provide native mobile access to your platform.
