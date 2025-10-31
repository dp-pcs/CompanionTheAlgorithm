# 📄 Backend Integration Guide for iOS Repository

**🎯 Purpose:** This file should be copied to the iOS repository (`mobile_thealgorithm`) to help iOS developers connect to the backend.

**📋 Filename in iOS repo:** `docs/BACKEND_INTEGRATION.md`

---

# Backend Integration - The Algorithm iOS App

This document describes how to integrate with The Algorithm backend API.

---

## 🔗 Backend Repository

**Repository:** git@github.com:dp-pcs/thealgorithm.git  
**Clone:** `git clone git@github.com:dp-pcs/thealgorithm.git`

**API Documentation:**
- [Complete API Specification](https://github.com/dp-pcs/thealgorithm/blob/main/docs/api/IOS_API_SPECIFICATION.md)
- [iOS Team Handoff](https://github.com/dp-pcs/thealgorithm/blob/main/mobile%20app/IOS_TEAM_HANDOFF.md)
- [Backend Integration Status](https://github.com/dp-pcs/thealgorithm/blob/main/mobile%20app/BACKEND_INTEGRATION_COMPLETE.md)

---

## 🚀 Quick Start

### Step 1: Get OAuth Client ID

Contact the backend team to register your iOS app:

**Backend team runs:**
```bash
cd thealgorithm
python scripts/register_ios_oauth_client.py
```

**You'll receive:**
- `client_id`: Something like `ios_app_abc123def456`

### Step 2: Configure iOS App

**Update `AuthenticationManager.swift`:**
```swift
// OAuth Configuration
private let oauthURL = "https://thealgorithm.live/oauth/authorize"
private let tokenURL = "https://thealgorithm.live/oauth/token"
private let clientID = "ios_app_abc123def456"  // From backend team
private let redirectURI = "thealgorithm://oauth/callback"

// API Configuration
private let baseURL = "https://thealgorithm.live/api"

// Security - MUST use PKCE for mobile apps
private let usePKCE = true  // REQUIRED
```

**Ensure `Info.plist` has URL scheme:**
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>thealgorithm</string>
        </array>
    </dict>
</array>
```

### Step 3: Test Backend Connection

**Health check (no auth required):**
```swift
let url = URL(string: "https://thealgorithm.live/api/health")!
URLSession.shared.dataTask(with: url) { data, response, error in
    // Should get: {"status": "healthy", "version": "1.0.0", ...}
    print(String(data: data!, encoding: .utf8)!)
}.resume()
```

---

## 📡 API Endpoints

### Base URL
```
https://thealgorithm.live
```

### Authentication Endpoints

**1. OAuth Authorization**
```
GET /oauth/authorize?
  client_id=<your_client_id>&
  redirect_uri=thealgorithm://oauth/callback&
  response_type=code&
  code_challenge=<pkce_challenge>&
  code_challenge_method=S256&
  state=<csrf_token>

Returns: Redirects to thealgorithm://oauth/callback?code=xxx&state=xxx
```

**2. Token Exchange**
```
POST /oauth/token
Content-Type: application/x-www-form-urlencoded

Body:
  grant_type=authorization_code
  client_id=<your_client_id>
  code=<auth_code>
  redirect_uri=thealgorithm://oauth/callback
  code_verifier=<pkce_verifier>

Returns: 
{
  "access_token": "eyJhbGc...",
  "token_type": "Bearer",
  "expires_in": 86400
}
```

### iOS-Specific Endpoints

**All require:** `Authorization: Bearer <access_token>` header

**3. Store Cookies**
```
POST /api/store-cookies
Authorization: Bearer <access_token>
Content-Type: application/json

Body:
{
  "cookies": [
    {
      "name": "auth_token",
      "value": "...",
      "domain": "x.com",
      "path": "/",
      "expires": 1735689600,
      "httpOnly": true,
      "secure": true
    }
  ],
  "timestamp": 1735689600
}

Returns:
{
  "success": true,
  "message": "Cookies stored successfully",
  "cookies_stored": 2
}
```

**4. Send Message**
```
POST /api/send-message
Authorization: Bearer <access_token>
Content-Type: application/json

Body:
{
  "message": "Hello from iOS!",
  "timestamp": 1735689600
}

Returns:
{
  "success": true,
  "message": "Message sent successfully via twikit",
  "tweet_id": "1234567890123456789"
}
```

**5. Health Check**
```
GET /api/health
(No authentication required)

Returns:
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": 1735689600
}
```

---

## 🔒 Security Requirements

### PKCE Implementation (Required)

```swift
// 1. Generate random code verifier (43-128 chars)
func generateCodeVerifier() -> String {
    var buffer = [UInt8](repeating: 0, count: 32)
    _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
    return Data(buffer).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
        .trimmingCharacters(in: .whitespaces)
}

// 2. Generate code challenge from verifier
func generateCodeChallenge(verifier: String) -> String {
    guard let data = verifier.data(using: .utf8) else { return "" }
    let hash = SHA256.hash(data: data)
    return Data(hash).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
        .trimmingCharacters(in: .whitespaces)
}

// 3. Use in OAuth flow
let verifier = generateCodeVerifier()
let challenge = generateCodeChallenge(verifier: verifier)

// Send challenge in /oauth/authorize
// Send verifier in /oauth/token
```

### Token Storage

```swift
// Store in Keychain (most secure)
import Security

func saveToken(_ token: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "access_token",
        kSecValueData as String: token.data(using: .utf8)!
    ]
    SecItemAdd(query as CFDictionary, nil)
}

func getToken() -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "access_token",
        kSecReturnData as String: true
    ]
    var result: AnyObject?
    SecItemCopyMatching(query as CFDictionary, &result)
    guard let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
}
```

---

## 🐛 Common Issues

### "Invalid client_id"
**Fix:** Contact backend team to register your app

### "PKCE verification failed"
**Fix:** Ensure you're sending the same `code_verifier` that generated the `code_challenge`

### "Subscription required"
**Fix:** User's trial expired, show upgrade screen

### "No cookies found"
**Fix:** User needs to authenticate with X.com first

---

## 📚 Complete Documentation

**Full API Reference:**
- [IOS_API_SPECIFICATION.md](https://github.com/dp-pcs/thealgorithm/blob/main/docs/api/IOS_API_SPECIFICATION.md)

**Setup Guide:**
- [IOS_TEAM_HANDOFF.md](https://github.com/dp-pcs/thealgorithm/blob/main/mobile%20app/IOS_TEAM_HANDOFF.md)

**Backend Details:**
- [BACKEND_INTEGRATION_COMPLETE.md](https://github.com/dp-pcs/thealgorithm/blob/main/mobile%20app/BACKEND_INTEGRATION_COMPLETE.md)

---

## 📞 Support

**Backend Issues:**
- Create issue: https://github.com/dp-pcs/thealgorithm/issues
- Label: `mobile-api`

**Questions:**
- Check docs first
- Create GitHub issue
- Tag backend team

---

**Backend Repository:** git@github.com:dp-pcs/thealgorithm.git  
**iOS Repository:** git@github.com:dp-pcs/mobile_thealgorithm.git  
**Last Updated:** October 31, 2025

