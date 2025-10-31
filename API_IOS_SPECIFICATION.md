# iOS Mobile App API Specification v1.0

**Base URL:** `https://thealgorithm.live`  
**Authentication:** OAuth 2.0 with PKCE + Bearer tokens  
**Last Updated:** October 31, 2025

---

## 🔐 Authentication Flow

### Step 1: Register iOS Client

**Backend Setup (Run Once):**
```bash
python scripts/register_ios_oauth_client.py
```

This generates a `client_id` for the iOS app.

### Step 2: OAuth Authorization

**Endpoint:** `GET /oauth/authorize`

**Parameters:**
- `client_id` (required) - Your iOS app client ID
- `redirect_uri` (required) - Must be: `thealgorithm://oauth/callback`
- `response_type` (required) - Must be: `code`
- `scope` (optional) - Space-separated: `read write`
- `state` (required) - CSRF token (random string)
- `code_challenge` (required) - PKCE challenge (base64url SHA256 of code_verifier)
- `code_challenge_method` (required) - Must be: `S256`

**Response:**
Redirects to: `thealgorithm://oauth/callback?code=xxx&state=xxx`

**Example:**
```
GET /oauth/authorize?
  client_id=ios_app_abc123&
  redirect_uri=thealgorithm://oauth/callback&
  response_type=code&
  scope=read%20write&
  state=random_csrf_token&
  code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&
  code_challenge_method=S256
```

### Step 3: Token Exchange

**Endpoint:** `POST /oauth/token`

**Headers:**
```
Content-Type: application/x-www-form-urlencoded
```

**Body (form-encoded):**
- `grant_type=authorization_code` (required)
- `client_id` (required) - Your iOS app client ID
- `code` (required) - Authorization code from step 2
- `redirect_uri` (required) - Must match: `thealgorithm://oauth/callback`
- `code_verifier` (required) - PKCE verifier (original random string)

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 86400,
  "scope": "read write"
}
```

**Example:**
```bash
curl -X POST https://thealgorithm.live/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=ios_app_abc123" \
  -d "code=auth_code_xyz" \
  -d "redirect_uri=thealgorithm://oauth/callback" \
  -d "code_verifier=original_random_string_43_to_128_chars"
```

**Token expires in 24 hours.** Store securely in iOS Keychain.

---

## 📱 iOS-Specific Endpoints

All endpoints require Bearer token authentication:
```
Authorization: Bearer <access_token>
```

### 1. Store Cookies

Store X.com session cookies extracted from WebView.

**Endpoint:** `POST /api/store-cookies`

**Request:**
```json
{
  "cookies": [
    {
      "name": "auth_token",
      "value": "encrypted_cookie_value",
      "domain": "x.com",
      "path": "/",
      "expires": 1735689600,
      "httpOnly": true,
      "secure": true
    },
    {
      "name": "ct0",
      "value": "csrf_token_value",
      "domain": "x.com",
      "path": "/",
      "expires": 1735689600,
      "httpOnly": false,
      "secure": true
    }
  ],
  "timestamp": 1735689600
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Cookies stored successfully",
  "cookies_stored": 2
}
```

**Error (400 Bad Request):**
```json
{
  "detail": "Invalid cookie data"
}
```

**Error (402 Payment Required):**
```json
{
  "detail": {
    "error": "subscription_required",
    "message": "Your trial has expired. Please subscribe to continue using The Algorithm.",
    "trial_end_date": "2025-10-15T12:00:00Z",
    "subscription_status": "trial_expired",
    "days_expired": 16,
    "upgrade_url": "/pricing"
  }
}
```

**Required Cookies:**
- `auth_token` - X.com authentication token
- `ct0` - CSRF token

### 2. Send Message

Post a tweet using stored X.com session cookies.

**Endpoint:** `POST /api/send-message`

**Request:**
```json
{
  "message": "Hello from The Algorithm iOS app!",
  "timestamp": 1735689600
}
```

**Constraints:**
- Message length: 1-280 characters
- User must have stored cookies (call `/api/store-cookies` first)
- User must have active subscription

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Message sent successfully via twikit",
  "tweet_id": "1234567890123456789"
}
```

**Error (400 Bad Request - No Cookies):**
```json
{
  "detail": {
    "error": "no_cookies",
    "message": "No X.com session cookies found. Please authenticate with X.com first."
  }
}
```

**Error (400 Bad Request - Invalid Cookies):**
```json
{
  "detail": {
    "error": "invalid_cookies",
    "message": "Missing required cookies: auth_token, ct0. Please re-authenticate with X.com."
  }
}
```

**Error (400 Bad Request - Posting Failed):**
```json
{
  "detail": {
    "error": "posting_failed",
    "message": "Failed to post tweet: API rate limit exceeded",
    "method_info": {
      "twikit": {"available": false, "reason": "Rate limited"},
      "api_client": {"available": false, "reason": "No keys"}
    }
  }
}
```

**Error (402 Payment Required):**
```json
{
  "detail": {
    "error": "subscription_required",
    "message": "Your trial has expired. Please subscribe to continue using The Algorithm.",
    "upgrade_url": "/pricing"
  }
}
```

### 3. Health Check

Verify API connectivity. No authentication required.

**Endpoint:** `GET /api/health`

**Response (200 OK):**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": 1735689600
}
```

### 4. API Key Status

Check user's LLM API key configuration and subscription tier.

**Endpoint:** `GET /api/api-key-status`

**Headers:**
```
Authorization: Bearer <access_token>
```

**Purpose:**  
Tells the iOS app whether the user needs to provide their own LLM API keys or can use system-provided keys.

**Response (200 OK):**
```json
{
  "key_source": "system",
  "plan_tier": "pro",
  "using_system_keys": true,
  "needs_own_keys": false,
  "available_providers": ["openai", "anthropic", "google"],
  "provider_details": {
    "openai": {
      "available": true,
      "source": "system"
    },
    "anthropic": {
      "available": true,
      "source": "system"
    },
    "google": {
      "available": true,
      "source": "system"
    }
  }
}
```

**Response Fields:**
- `key_source` - Where keys come from: `"system"` or `"user"`
- `plan_tier` - User's subscription: `"starter"`, `"pro"`, `"pro_plus"`, `"free"`
- `using_system_keys` - `true` if user can use system keys (Pro/Pro+)
- `needs_own_keys` - `true` if user must provide their own keys (Starter)
- `available_providers` - List of providers with configured keys
- `provider_details` - Per-provider availability and source

**Example Responses:**

**Pro User (System Keys):**
```json
{
  "key_source": "system",
  "plan_tier": "pro",
  "using_system_keys": true,
  "needs_own_keys": false,
  "available_providers": ["openai", "anthropic"],
  "provider_details": {
    "openai": {"available": true, "source": "system"},
    "anthropic": {"available": true, "source": "system"},
    "google": {"available": false, "source": null}
  }
}
```

**Starter User (Own Keys):**
```json
{
  "key_source": "user",
  "plan_tier": "starter",
  "using_system_keys": false,
  "needs_own_keys": true,
  "available_providers": ["openai"],
  "provider_details": {
    "openai": {"available": true, "source": "user"},
    "anthropic": {"available": false, "source": null},
    "google": {"available": false, "source": null}
  }
}
```

**Starter User (No Keys Configured):**
```json
{
  "key_source": "user",
  "plan_tier": "starter",
  "using_system_keys": false,
  "needs_own_keys": true,
  "available_providers": [],
  "provider_details": {
    "openai": {"available": false, "source": null},
    "anthropic": {"available": false, "source": null},
    "google": {"available": false, "source": null}
  }
}
```

**iOS App Usage:**
```swift
// Call on app launch and after login
func checkAPIKeyStatus() async throws {
    let url = URL(string: "\(baseURL)/api-key-status")!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    
    let (data, _) = try await URLSession.shared.data(for: request)
    let status = try JSONDecoder().decode(APIKeyStatusResponse.self, from: data)
    
    if status.needs_own_keys && status.available_providers.isEmpty {
        // Show "Add API Keys" screen
        presentAPIKeySetup()
    } else {
        // User is ready to use LLM features
        enableLLMFeatures()
    }
}
```

---

## 🔒 Security Requirements

### Authentication
- ✅ Use PKCE flow (no client secret)
- ✅ Generate cryptographically random `code_verifier` (43-128 chars)
- ✅ Generate `code_challenge` = base64url(SHA256(code_verifier))
- ✅ Store access token in iOS Keychain
- ✅ Include `Authorization: Bearer <token>` header on all API calls

### URL Scheme
- ✅ Register `thealgorithm` URL scheme in Info.plist
- ✅ Handle redirect: `thealgorithm://oauth/callback?code=xxx&state=xxx`
- ✅ Validate state parameter matches CSRF token

### Cookie Extraction
- ✅ Use WKWebView for X.com login
- ✅ Extract cookies from `WKWebsiteDataStore.httpCookieStore`
- ✅ Filter for x.com/twitter.com domain cookies only
- ✅ Send cookies to backend immediately after extraction
- ✅ Clear WebView cookies after extraction (security)

### Data Storage
- ✅ Store access token in Keychain
- ✅ Never log tokens or cookies
- ✅ Use HTTPS for all API calls
- ✅ Validate SSL certificates

---

## 🧪 Testing Checklist

### Prerequisites
- [ ] Backend running at https://thealgorithm.live
- [ ] OAuth client registered (client_id obtained)
- [ ] User has active account with trial or subscription

### Authentication Flow
- [ ] App can open OAuth web view
- [ ] User can log in with X OAuth
- [ ] App receives authorization code via redirect
- [ ] App exchanges code for access token
- [ ] Token is stored in Keychain

### Cookie Flow
- [ ] App can open X.com WebView
- [ ] User can log in to X.com
- [ ] App extracts cookies after login
- [ ] Cookies are sent to `/api/store-cookies`
- [ ] Backend confirms storage

### Posting Flow
- [ ] User can type message (1-280 chars)
- [ ] Tapping "Send" calls `/api/send-message`
- [ ] Tweet appears on X.com
- [ ] App shows success message with tweet_id

### Error Handling
- [ ] Expired token shows auth error
- [ ] No cookies shows "authenticate with X.com" error
- [ ] Expired subscription shows upgrade prompt
- [ ] Network errors show user-friendly message

---

## 📊 Rate Limits

**OAuth Endpoints:**
- `/oauth/authorize` - No limit (web flow)
- `/oauth/token` - 10 requests/minute per client

**API Endpoints:**
- `/api/store-cookies` - 10 requests/minute per user
- `/api/send-message` - Subject to X.com rate limits (see posting service)

---

## 🐛 Common Issues

### "Invalid client_id"
**Cause:** OAuth client not registered  
**Fix:** Run `python scripts/register_ios_oauth_client.py`

### "Invalid redirect_uri"
**Cause:** Redirect URI mismatch  
**Fix:** Must be exactly `thealgorithm://oauth/callback`

### "PKCE verification failed"
**Cause:** code_verifier doesn't match code_challenge  
**Fix:** Ensure you're using the same verifier used to generate challenge

### "No cookies found"
**Cause:** User hasn't authenticated with X.com yet  
**Fix:** Prompt user to authenticate with X.com first

### "Subscription expired"
**Cause:** User's trial ended and they haven't subscribed  
**Fix:** Show upgrade prompt with `/pricing` URL

---

## 🔄 API Versioning

**Current Version:** v1.0  
**Stability:** Stable  
**Breaking Changes:** Will be announced 30 days in advance

**Subscribe to updates:**
- Watch this repository for changes
- Check CHANGELOG.md for API updates

---

## 📞 Support

**Backend Issues:**
- Repository: https://github.com/dp-pcs/thealgorithm
- Issues: Create GitHub issue with `mobile-api` label

**iOS App Issues:**
- Repository: git@github.com:dp-pcs/mobile_thealgorithm.git
- Clone: `git clone git@github.com:dp-pcs/mobile_thealgorithm.git`
- Contact: iOS team lead

---

**Last Updated:** October 31, 2025  
**API Version:** 1.0  
**Backend Version:** 1.1

