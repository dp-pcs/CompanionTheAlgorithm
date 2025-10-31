# 📱 iOS Team Handoff Document

**Date:** October 31, 2025  
**Status:** Backend Ready ✅ | iOS App Needed ❌

---

## 🎯 Quick Summary

**What's Ready:**
- ✅ Backend OAuth provider fully implemented
- ✅ iOS API endpoints (/api/store-cookies, /api/send-message)
- ✅ Database schema and authentication system
- ✅ Complete API documentation

**What's Missing:**
- ❌ iOS app source code (Swift, Xcode project)
- ❌ OAuth client registration (takes 2 minutes)
- ❌ Connection between iOS app and backend

**What You Need to Do:**
1. Build iOS app (or share existing repo with backend team)
2. Register OAuth client
3. Configure iOS app with credentials
4. Test end-to-end

---

## 📋 Backend Status

### Implemented Endpoints

| Endpoint | Method | Status | Purpose |
|----------|--------|--------|---------|
| `/oauth/authorize` | GET | ✅ Ready | OAuth authorization (step 1) |
| `/oauth/token` | POST | ✅ Ready | Token exchange (step 2) |
| `/api/store-cookies` | POST | ✅ Ready | Store X.com cookies |
| `/api/send-message` | POST | ✅ Ready | Post tweet |
| `/api/health` | GET | ✅ Ready | Health check |

### Database Tables Created

- ✅ `oauth_clients` - OAuth app registrations
- ✅ `oauth_authorization_codes` - Temporary auth codes
- ✅ `oauth_access_tokens` - JWT access tokens
- ✅ `x_sessions` - X.com session storage
- ✅ `x_session_cookies` - Cookie storage

### Security Features

- ✅ PKCE (Proof Key for Code Exchange)
- ✅ JWT token signing & validation
- ✅ Token expiration (24 hours)
- ✅ Cookie encryption at rest
- ✅ CSRF protection via state parameter
- ✅ Subscription verification

---

## 🔧 Setup Instructions

### Step 1: Register iOS Client

**Location:** Run from backend repository root

```bash
cd /Users/davidproctor/Documents/GitHub/thealgorithm
python scripts/register_ios_oauth_client.py
```

**Output:**
```
✅ Successfully registered iOS app as OAuth client!

Client ID:        ios_app_a1b2c3d4e5f6g7h8
Client Type:      public (mobile app)
Redirect URI:     thealgorithm://oauth/callback
Allowed Scopes:   read, write
Is Trusted:       Yes (skip consent screen)
```

**Save the `client_id`** - you'll need it in Step 2.

### Step 2: Configure iOS App

**In your iOS app, update these configuration values:**

**File: `AuthenticationManager.swift` (or equivalent)**
```swift
// OAuth Configuration
private let oauthURL = "https://thealgorithm.live/oauth/authorize"
private let tokenURL = "https://thealgorithm.live/oauth/token"
private let clientID = "ios_app_a1b2c3d4e5f6g7h8"  // From Step 1
private let redirectURI = "thealgorithm://oauth/callback"

// Must use PKCE
private let usePKCE = true  // REQUIRED
```

**File: `APIClient.swift` (or equivalent)**
```swift
private let baseURL = "https://thealgorithm.live/api"
```

**File: `Info.plist`**
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

### Step 3: Test Authentication Flow

**Test Sequence:**

1. **OAuth Login**
   ```
   User taps "Login" button
   → App opens: https://thealgorithm.live/oauth/authorize?
       client_id=ios_app_abc123&
       redirect_uri=thealgorithm://oauth/callback&
       response_type=code&
       code_challenge=xxx&
       code_challenge_method=S256&
       state=random_csrf_token
   → User logs in with X OAuth on web
   → Backend redirects to: thealgorithm://oauth/callback?code=xxx&state=xxx
   → App captures code
   ```

2. **Token Exchange**
   ```
   App sends POST to /oauth/token with:
   - grant_type: authorization_code
   - client_id: ios_app_abc123
   - code: (from step 1)
   - redirect_uri: thealgorithm://oauth/callback
   - code_verifier: (PKCE verifier)
   
   Backend responds with:
   {
     "access_token": "eyJhbGc...",
     "token_type": "Bearer",
     "expires_in": 86400
   }
   
   App stores token in Keychain
   ```

3. **X.com Cookie Extraction**
   ```
   User taps "Connect X Account"
   → App opens WKWebView to https://x.com/login
   → User logs in to X.com
   → App extracts cookies from WKWebView:
       - auth_token
       - ct0
       - auth_multi (if available)
       - twid (if available)
   → App sends to /api/store-cookies with Bearer token
   ```

4. **Post Tweet**
   ```
   User types message and taps "Post"
   → App sends POST to /api/send-message:
   {
     "message": "Hello from iOS!",
     "timestamp": 1735689600
   }
   with Header: Authorization: Bearer <token>
   
   → Backend posts tweet using stored cookies
   → Returns tweet_id
   ```

---

## 📚 Documentation

### For iOS Developers

**Primary Reference:**
- [iOS API Specification](../docs/api/IOS_API_SPECIFICATION.md)
  - Complete API contract
  - Request/response examples
  - Error handling
  - Security requirements

**Backend Code Reference:**
- [iOS App Endpoints](../app/api/v1/endpoints/ios_app.py)
  - See exact request/response schemas
  - See validation logic
  - See error codes

**Setup Documentation:**
- [Backend Integration Complete](./BACKEND_INTEGRATION_COMPLETE.md)
  - Overview of what's implemented
  - API flow diagrams
  - Security details

### Authentication Details

**PKCE Flow (Required for iOS):**
```swift
// 1. Generate random verifier (43-128 chars)
let codeVerifier = generateRandomString(length: 64)

// 2. Generate challenge
let codeChallenge = base64URLEncode(SHA256(codeVerifier))

// 3. Send challenge in authorize request
// 4. Send verifier in token request
// 5. Backend validates they match
```

**Token Storage:**
```swift
// Store in Keychain (most secure)
let keychain = KeychainSwift()
keychain.set(accessToken, forKey: "access_token")
```

**API Calls:**
```swift
// Include token in all API requests
var request = URLRequest(url: url)
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
```

---

## 🚨 Common Issues & Solutions

### Issue: "Invalid client_id"
**Cause:** OAuth client not registered  
**Fix:** Run `python scripts/register_ios_oauth_client.py`

### Issue: "Invalid redirect_uri"
**Cause:** Mismatch between registered URI and request  
**Fix:** Must be exactly `thealgorithm://oauth/callback`

### Issue: "PKCE verification failed"
**Cause:** code_verifier doesn't match code_challenge  
**Fix:** Use same verifier that generated the challenge

### Issue: "Subscription required"
**Cause:** User's trial expired  
**Fix:** Show upgrade screen with `/pricing` URL

### Issue: "No cookies found"
**Cause:** User hasn't authenticated with X.com  
**Fix:** Show "Connect X Account" flow first

### Issue: "Invalid cookies"
**Cause:** Missing required cookies or cookies expired  
**Fix:** Prompt user to re-authenticate with X.com

---

## 🧪 Testing Checklist

### Prerequisites
- [ ] Backend running at https://thealgorithm.live
- [ ] OAuth client registered
- [ ] Test user account created
- [ ] Test user has active trial or subscription

### OAuth Flow
- [ ] App can open OAuth URL in browser/web view
- [ ] User can log in with X OAuth
- [ ] App receives redirect with code
- [ ] App validates state parameter (CSRF check)
- [ ] App exchanges code for token
- [ ] Token stored in Keychain

### Cookie Flow
- [ ] App opens WKWebView to x.com
- [ ] User can log in to X.com
- [ ] App extracts cookies after login
- [ ] Required cookies present (auth_token, ct0)
- [ ] POST /api/store-cookies succeeds
- [ ] Backend returns 200 with cookies_stored count

### Posting Flow
- [ ] User can type message
- [ ] Message length validated (1-280 chars)
- [ ] POST /api/send-message succeeds
- [ ] Tweet appears on X.com
- [ ] Tweet ID returned to app

### Error Handling
- [ ] Network errors show user-friendly message
- [ ] Expired token triggers re-authentication
- [ ] Expired subscription shows upgrade prompt
- [ ] Missing cookies prompts X.com login
- [ ] Rate limits handled gracefully

---

## 📊 Expected Backend Behavior

### Successful Cookie Storage
```
POST /api/store-cookies

Request:
{
  "cookies": [
    {"name": "auth_token", "value": "...", ...},
    {"name": "ct0", "value": "...", ...}
  ],
  "timestamp": 1735689600
}

Response (200 OK):
{
  "success": true,
  "message": "Cookies stored successfully",
  "cookies_stored": 2
}

Backend Action:
- Creates/updates XSession for user
- Encrypts cookie values
- Stores in x_session_cookies table
- Links to user via user_id from JWT token
```

### Successful Tweet Posting
```
POST /api/send-message

Request:
{
  "message": "Hello from iOS!",
  "timestamp": 1735689600
}

Response (200 OK):
{
  "success": true,
  "message": "Message sent successfully via twikit",
  "tweet_id": "1234567890123456789"
}

Backend Action:
- Validates user subscription
- Retrieves stored cookies for user
- Calls unified_posting_service
- Attempts posting via twikit → API client → other methods
- Returns tweet ID on success
```

---

## 🔒 Security Requirements

### iOS App Must Implement:
- ✅ PKCE flow (no client secret in app)
- ✅ Keychain storage for tokens
- ✅ CSRF validation (state parameter)
- ✅ SSL certificate pinning (recommended)
- ✅ Token expiration handling
- ✅ Secure cookie extraction from WebView
- ✅ Clear WebView data after cookie extraction

### Do NOT:
- ❌ Store tokens in UserDefaults
- ❌ Store tokens in plain files
- ❌ Log tokens or cookies
- ❌ Send tokens in URL parameters
- ❌ Use client secret (mobile apps are "public" clients)

---

## 📞 Contact & Support

### Backend Issues
**Repository:** https://github.com/dp-pcs/thealgorithm  
**Questions:** Create issue with `mobile-api` label  
**Contact:** Backend team lead

### iOS App Development
**Repository:** git@github.com:dp-pcs/mobile_thealgorithm.git  
**Clone:** `git clone git@github.com:dp-pcs/mobile_thealgorithm.git`  
**Questions:** Create issue in iOS repo  
**Contact:** iOS team lead

---

## 🎯 Next Steps

**For iOS Team:**
1. [ ] Review [iOS API Specification](../docs/api/IOS_API_SPECIFICATION.md)
2. [ ] Build iOS app or share existing repo
3. [ ] Contact backend team to register OAuth client
4. [ ] Configure iOS app with credentials
5. [ ] Implement authentication flow
6. [ ] Test end-to-end with backend
7. [ ] Report any issues or API questions

**For Backend Team:**
1. [x] OAuth provider implemented
2. [x] iOS endpoints implemented
3. [x] Documentation created
4. [ ] Register iOS OAuth client when ready
5. [ ] Monitor logs during iOS testing
6. [ ] Be available for questions

---

## 📝 API Quick Reference

**Base URL:** `https://thealgorithm.live`

**OAuth Flow:**
```
1. GET /oauth/authorize?client_id=xxx&redirect_uri=xxx&code_challenge=xxx
   → Returns: Redirect to thealgorithm://oauth/callback?code=xxx

2. POST /oauth/token (client_id, code, code_verifier)
   → Returns: {"access_token": "xxx", "expires_in": 86400}
```

**API Calls:**
```
3. POST /api/store-cookies (Bearer token, cookies array)
   → Returns: {"success": true, "cookies_stored": N}

4. POST /api/send-message (Bearer token, message text)
   → Returns: {"success": true, "tweet_id": "xxx"}
```

**All API calls require:** `Authorization: Bearer <access_token>`

---

**Last Updated:** October 31, 2025  
**Backend Version:** 1.1  
**Ready for iOS Development:** ✅ Yes

