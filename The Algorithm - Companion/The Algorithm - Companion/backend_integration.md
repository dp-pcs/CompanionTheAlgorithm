### OAuth Provider Setup for iOS App

This document explains the OAuth provider implementation that allows the iOS mobile app (and other third-party applications) to authenticate against thealgorithm.live.

## Overview

**What is this?**

thealgorithm.live now acts as both:
1. **OAuth Client** - Uses X (Twitter) OAuth to authenticate web users
2. **OAuth Provider** - Provides OAuth for iOS app to authenticate mobile users

These systems work independently and do not interfere with each other.

## Architecture

### Existing X OAuth (Unchanged)
```
User → thealgorithm.live → X.com → thealgorithm.live
       (Client)                     (receives token)
```

### New OAuth Provider (for iOS)
```
iOS App → thealgorithm.live → iOS App
          (Provider)           (receives token)
```

## Components

### 1. Database Models (`app/models/oauth_provider.py`)

Three new tables:

- **`oauth_clients`** - Registered OAuth applications (iOS app, future Android app, etc.)
- **`oauth_authorization_codes`** - Temporary codes (10-minute expiry, single-use)
- **`oauth_access_tokens`** - Long-lived JWT tokens (24-hour expiry)

### 2. API Endpoints

#### OAuth Provider Endpoints (`/oauth/*`)

```
GET  /oauth/authorize       - Authorization endpoint (step 1)
POST /oauth/token          - Token exchange endpoint (step 2)
POST /oauth/revoke         - Revoke access token

GET  /oauth/provider/clients          - List OAuth clients (admin)
POST /oauth/provider/clients          - Create OAuth client (admin)
GET  /oauth/provider/clients/{id}     - Get client details (admin)
PATCH /oauth/provider/clients/{id}    - Update client (admin)
DELETE /oauth/provider/clients/{id}   - Delete client (admin)

GET  /oauth/provider/my/tokens        - List user's tokens
DELETE /oauth/provider/my/tokens/{client_id} - Revoke client access
```

#### iOS App Endpoints (`/api/*`)

```
POST /api/store-cookies    - Store X.com session cookies (requires OAuth token)
POST /api/send-message     - Send message/tweet (requires OAuth token)
GET  /api/health           - Health check (no auth required)
```

### 3. Authentication Dependencies

New authentication helpers in `app/api/deps.py`:

- **`get_current_user_from_token()`** - Validates OAuth JWT tokens
- **`get_current_user_hybrid()`** - Accepts either session OR token

## OAuth Flow

### Step 1: Authorization Request

iOS app opens this URL in ASWebAuthenticationSession:

```
https://thealgorithm.live/oauth/authorize?
  client_id=ios_app_abc123&
  redirect_uri=thealgorithm://oauth/callback&
  response_type=code&
  scope=read,write&
  state=random_csrf_token&
  code_challenge=SHA256_hash&
  code_challenge_method=S256
```

### Step 2: User Authentication

If user isn't logged in:
- Redirect to `/login?next=/oauth/authorize`
- User logs in with X OAuth
- Return to authorization page

If user is logged in:
- Show consent screen (skipped for trusted apps)
- Generate authorization code
- Redirect to: `thealgorithm://oauth/callback?code=ABC123&state=...`

### Step 3: Token Exchange

iOS app calls:

```http
POST /oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&
code=ABC123&
client_id=ios_app_abc123&
redirect_uri=thealgorithm://oauth/callback&
code_verifier=original_random_string
```

Response:

```json
{
  "access_token": "eyJhbGc...JWT_TOKEN",
  "token_type": "Bearer",
  "expires_in": 86400,
  "scope": "read,write"
}
```

### Step 4: API Calls

iOS app uses the access token for all API calls:

```http
POST /api/store-cookies
Authorization: Bearer eyJhbGc...JWT_TOKEN
Content-Type: application/json

{
  "cookies": [
    {
      "name": "auth_token",
      "value": "...",
      "domain": "x.com",
      "path": "/",
      "expires": 1234567890,
      "httpOnly": true,
      "secure": true
    }
  ],
  "timestamp": 1234567890
}
```

## Security Features

### PKCE (Proof Key for Code Exchange)

Mobile apps can't securely store secrets, so we use PKCE:

1. iOS app generates random `code_verifier`
2. iOS app sends SHA256 hash as `code_challenge` in authorize request
3. iOS app sends original `code_verifier` in token request
4. Backend verifies hash matches

This prevents authorization code interception attacks.

### JWT Tokens

Access tokens are JWTs signed with `JWT_SECRET_KEY`:

```json
{
  "sub": "user_id",
  "client_id": "ios_app_abc123",
  "scope": "read,write",
  "exp": 1234567890,
  "iat": 1234567800,
  "jti": "unique_token_id"
}
```

### Token Storage

- JWT tokens are hashed (SHA256) and stored in database
- Tokens can be revoked by user or admin
- Expired tokens are automatically rejected

### Secure Cookie Storage

When iOS app sends X.com cookies:
- Stored in `x_sessions` and `x_session_cookies` tables
- Associated with user and marked as `ios_app` source
- Can be used for X API calls on user's behalf

## Setup Instructions

### 1. Run Database Migration

```bash
alembic upgrade head
```

This creates the three OAuth provider tables.

### 2. Register iOS App as OAuth Client

```bash
python scripts/register_ios_oauth_client.py
```

This will:
- Create OAuth client record
- Generate client ID
- Display client ID to add to iOS app

Output:
```
Client ID:        ios_app_abc123def456
Client Type:      public (mobile app)
Redirect URI:     thealgorithm://oauth/callback
Allowed Scopes:   read, write
Is Trusted:       Yes
```

### 3. Update iOS App

Edit `AuthenticationManager.swift` (line 11):

```swift
private let clientID = "ios_app_abc123def456"  // Use YOUR client ID
```

### 4. Test OAuth Flow

1. Build and run iOS app
2. Tap "Authenticate with Your Service"
3. Log in to thealgorithm.live (if not already logged in)
4. Get redirected back to iOS app
5. Verify status shows "Authenticated"

### 5. Test Cookie Storage

1. In iOS app, tap "Authenticate with X.com"
2. Log in to X.com in WebView
3. Cookies are automatically extracted and sent to backend
4. Verify in database: `select * from x_sessions where created_via = 'ios_app';`

### 6. Test Message Sending

1. Type a message in iOS app
2. Tap "Send Message"
3. Message is sent to `/api/send-message`
4. Backend uses stored cookies to post tweet

## Configuration

### Environment Variables

```bash
# OAuth Provider Settings (already in app/core/config.py)
OAUTH_PROVIDER_ACCESS_TOKEN_EXPIRE_HOURS=24
OAUTH_PROVIDER_AUTHORIZATION_CODE_EXPIRE_MINUTES=10
OAUTH_PROVIDER_REQUIRE_PKCE=true
```

### Client Types

**Public Clients** (mobile apps)
- No client secret
- MUST use PKCE
- Tokens expire in 24 hours

**Confidential Clients** (server-side apps)
- Has client secret
- Optional PKCE
- Can use refresh tokens

## iOS App Changes Needed

### Current iOS App Configuration

The iOS app in `mobile app/` folder expects:

```swift
// AuthenticationManager.swift
private let oauthURL = "https://thealgorithm.live/oauth/authorize"
private let redirectURI = "thealgorithm://oauth/callback"
private let clientID = "your_client_id"  // ← UPDATE THIS

// APIClient.swift
private let baseURL = "https://thealgorithm.live/api"
private let tokenURL = "https://thealgorithm.live/oauth/token"
```

### What to Update

**Only one change needed:**

1. Update `clientID` in `AuthenticationManager.swift` with the client ID from step 2 above

That's it! Everything else is already configured correctly.

## Admin Management

### List All OAuth Clients

```bash
GET /api/v1/oauth/provider/clients
Authorization: Bearer <admin_session_token>
```

### View User's Connected Apps

```bash
GET /api/v1/oauth/provider/my/tokens
Authorization: Bearer <session_token>
```

### Revoke Client Access

```bash
DELETE /api/v1/oauth/provider/my/tokens/{client_id}
Authorization: Bearer <session_token>
```

## Troubleshooting

### iOS App: "Invalid client_id"

**Cause:** Client not registered or inactive

**Fix:**
1. Run `python scripts/register_ios_oauth_client.py`
2. Check database: `select * from oauth_clients;`
3. Verify `is_active = true`

### iOS App: "Invalid redirect_uri"

**Cause:** Mismatch between iOS app and backend

**Fix:**
1. iOS app uses: `thealgorithm://oauth/callback`
2. Backend must have exact same URI in `oauth_clients.redirect_uris`

### Token Exchange: "Invalid code"

**Cause:** Code expired or already used

**Fix:**
- Authorization codes expire in 10 minutes
- Codes can only be used once
- Start OAuth flow again

### Token Exchange: "PKCE verification failed"

**Cause:** code_verifier doesn't match code_challenge

**Fix:**
- iOS app must send same `code_verifier` used to generate `code_challenge`
- Check iOS app's PKCE implementation

### API Call: "Invalid access token"

**Cause:** Token expired, revoked, or invalid

**Fix:**
1. Check token expiration (24 hours)
2. Check if token was revoked
3. Get new token via OAuth flow

### Cookies Not Stored

**Cause:** Missing authentication or validation error

**Fix:**
1. Verify Bearer token is sent in Authorization header
2. Check user has permission to store cookies
3. Verify cookie data format matches schema

## Development vs Production

### Development

- Use `http://localhost:3000` for testing
- Update CORS settings in `app/main.py`
- Add localhost redirect URI for testing: `http://localhost:3000/callback`

### Production

- HTTPS required (iOS enforces this)
- Certificate must be valid
- Update `BACKEND_CORS_ORIGINS` in production `.env`

## Security Checklist

- ✅ PKCE required for mobile apps
- ✅ Authorization codes expire in 10 minutes
- ✅ Authorization codes single-use only
- ✅ Access tokens expire in 24 hours
- ✅ Tokens stored as SHA256 hashes
- ✅ JWT tokens signed and validated
- ✅ HTTPS enforced in production
- ✅ CSRF protection via state parameter
- ✅ Redirect URI validation
- ✅ Scope validation
- ✅ Token revocation supported

## API Reference

### Complete Endpoint List

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/oauth/authorize` | GET | Session | Start OAuth flow |
| `/oauth/token` | POST | None | Exchange code for token |
| `/oauth/revoke` | POST | Session | Revoke token |
| `/oauth/provider/clients` | GET/POST | Admin | Manage clients |
| `/oauth/provider/my/tokens` | GET | Session/Token | View connected apps |
| `/api/store-cookies` | POST | Token | Store X cookies |
| `/api/send-message` | POST | Token | Send tweet |
| `/api/health` | GET | None | Health check |

## Future Enhancements

### Potential Additions

1. **Refresh Tokens** - Long-lived tokens for token renewal
2. **Android App** - Register Android app as second OAuth client
3. **Rate Limiting** - Per-client rate limits
4. **Webhook Support** - Notify apps of events
5. **Granular Scopes** - `tweets.read`, `tweets.write`, `users.read`, etc.
6. **OAuth 2.1** - Upgrade to latest OAuth spec

## Questions?

Check these resources:

- **iOS App Docs:** `mobile app/setup_guide.md`
- **OAuth 2.0 Spec:** https://oauth.net/2/
- **PKCE Spec:** https://oauth.net/2/pkce/
- **JWT Spec:** https://jwt.io/introduction

---

**Ready to test?** Run the setup script and update your iOS app!

```bash
python scripts/register_ios_oauth_client.py
```

