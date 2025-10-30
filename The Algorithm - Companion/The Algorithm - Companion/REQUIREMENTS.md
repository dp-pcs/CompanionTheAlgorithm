# 📋 Requirements - The Algorithm iOS App

## Overview

This document outlines everything you need to get the iOS app tested and deployed with your thealgorithm.live backend.

## ✅ What's Already Done

The iOS app is pre-configured for thealgorithm.live:

- ✅ OAuth URL: `https://thealgorithm.live/oauth/authorize`
- ✅ Token URL: `https://thealgorithm.live/oauth/token`
- ✅ API Base URL: `https://thealgorithm.live/api`
- ✅ URL Scheme: `thealgorithm://oauth/callback`
- ✅ All Swift code complete and functional
- ✅ UI/UX implemented
- ✅ Security (Keychain) configured
- ✅ Error handling implemented

## 🔧 What You Need to Configure

### 1. OAuth Client ID (Required)

**Where:** `TwitterCookieApp/AuthenticationManager.swift`, line 11

```swift
private let clientID = "your_client_id"  // ← UPDATE THIS
```

**How to get it:**
1. Go to your thealgorithm.live admin/developer dashboard
2. Create a new OAuth application
3. Set redirect URI to: `thealgorithm://oauth/callback`
4. Copy the client ID
5. Paste it in the Swift file

### 2. Backend Endpoints (Required)

Your thealgorithm.live backend must implement these endpoints:

#### OAuth Endpoints (Standard OAuth 2.0)

```
GET https://thealgorithm.live/oauth/authorize
Parameters:
  - client_id: string (your OAuth client ID)
  - redirect_uri: "thealgorithm://oauth/callback"
  - response_type: "code"
  - scope: "read write"
  - state: string (CSRF token)

Returns: Redirect to thealgorithm://oauth/callback?code=XXX&state=XXX
```

```
POST https://thealgorithm.live/oauth/token
Content-Type: application/x-www-form-urlencoded

Body:
  - grant_type: "authorization_code"
  - client_id: string
  - code: string (from authorize callback)
  - redirect_uri: "thealgorithm://oauth/callback"

Returns:
{
  "access_token": "string",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "string" (optional)
}
```

#### API Endpoints

```
POST https://thealgorithm.live/api/store-cookies
Headers:
  - Authorization: Bearer <access_token>
  - Content-Type: application/json

Body:
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
    },
    {
      "name": "ct0",
      "value": "...",
      "domain": "x.com",
      "path": "/",
      "expires": 1234567890,
      "httpOnly": false,
      "secure": true
    }
  ],
  "timestamp": 1234567890
}

Returns:
{
  "success": true
}
```

```
POST https://thealgorithm.live/api/send-message
Headers:
  - Authorization: Bearer <access_token>
  - Content-Type: application/json

Body:
{
  "message": "Hello from iOS!",
  "timestamp": 1234567890
}

Returns:
{
  "success": true,
  "message_id": "string" (optional)
}
```

```
GET https://thealgorithm.live/api/health
Optional health check endpoint

Returns:
{
  "status": "healthy",
  "version": "1.0.0"
}
```

## 🛠️ Development Setup Requirements

### macOS Development Machine

- **macOS:** 13.0 (Ventura) or later
- **Xcode:** 15.0 or later ([Download from App Store](https://apps.apple.com/us/app/xcode/id497799835))
- **iOS Simulator:** Included with Xcode
- **Command Line Tools:** Installed with Xcode

### Apple Developer Account

**For Simulator Testing:** Free (no account needed)
- ✅ Can run on iOS Simulator
- ✅ Can test all features except push notifications

**For Device Testing:** Free Apple ID
- ✅ Can install on your own iPhone
- ✅ App expires after 7 days, requires rebuild
- ❌ Cannot distribute to other users
- ❌ Cannot submit to App Store

**For App Store:** Paid Developer Account ($99/year)
- ✅ Can distribute via TestFlight
- ✅ Can submit to App Store
- ✅ Apps don't expire
- ✅ Advanced features (push notifications, etc.)

## 📱 Testing Requirements

### Minimum Test Setup

1. **Xcode installed** on macOS
2. **OAuth client ID** configured in app
3. **thealgorithm.live backend** running with required endpoints
4. **Internet connection** (for OAuth and X.com login)

### Recommended Test Setup

1. All of the above, plus:
2. **Real iPhone device** for realistic testing
3. **Apple Developer account** (free) for device testing
4. **SSL certificate** for thealgorithm.live (HTTPS required)

### Test Checklist

- [ ] App builds without errors in Xcode
- [ ] OAuth authorization flow completes successfully
- [ ] Token exchange returns valid access token
- [ ] X.com WebView loads login page
- [ ] User can log into X.com
- [ ] Cookies are extracted after X.com login
- [ ] Cookies are stored in Keychain
- [ ] `/api/store-cookies` endpoint receives cookies
- [ ] Message can be sent via `/api/send-message`
- [ ] Error messages display correctly

## 🚀 Production Deployment Requirements

### App Store Submission

1. **Paid Apple Developer Account** ($99/year)
   - [Enroll here](https://developer.apple.com/programs/enroll/)

2. **App Store Connect Account**
   - Created automatically with Developer account

3. **Bundle Identifier**
   - Update in Xcode project settings
   - Recommended: `live.thealgorithm.ios` or similar
   - Must be unique across App Store

4. **App Icon**
   - Add to `Assets.xcassets/AppIcon.appiconset/`
   - Required sizes: 1024x1024 (store), 180x180, 167x167, 152x152, 120x120, 87x87, 80x80, 76x76, 60x60, 58x58, 40x40, 29x29, 20x20
   - Can generate from single 1024x1024 image using [appicon.co](https://www.appicon.co/)

5. **App Store Listing**
   - App name: "The Algorithm"
   - Description
   - Keywords
   - Screenshots (required for 6.5" and 5.5" displays)
   - Privacy Policy URL
   - Support URL

6. **Privacy Policy**
   - Required because app collects login credentials
   - Host on thealgorithm.live
   - Must disclose:
     - OAuth token collection
     - X.com cookie collection
     - Data storage practices
     - Third-party services used

### Backend Production Requirements

1. **SSL/TLS Certificate**
   - thealgorithm.live must use HTTPS
   - Valid SSL certificate (Let's Encrypt is fine)

2. **OAuth Provider**
   - Fully functional OAuth 2.0 implementation
   - Client ID registered for iOS app
   - Redirect URI: `thealgorithm://oauth/callback`

3. **API Endpoints**
   - All endpoints listed above implemented
   - Bearer token authentication
   - Error handling (return appropriate HTTP status codes)

4. **Database**
   - Store user tokens securely
   - Store user cookies securely
   - Encrypt sensitive data at rest

5. **Rate Limiting**
   - Prevent API abuse
   - Recommended: 100 requests per hour per user

6. **Monitoring**
   - Error logging
   - API usage tracking
   - Uptime monitoring

## 🔒 Security Requirements

### iOS App
- ✅ Already using iOS Keychain for secure storage
- ✅ Already using HTTPS-only connections
- ✅ Already implementing CSRF protection
- ✅ Already validating OAuth state parameter

### Backend
- [ ] Use HTTPS for all endpoints
- [ ] Validate OAuth tokens on all API requests
- [ ] Sanitize user input
- [ ] Rate limit API endpoints
- [ ] Log security events (failed logins, etc.)
- [ ] Encrypt database at rest
- [ ] Use secure session storage
- [ ] Implement token expiration/refresh

## 📊 Backend Implementation Example

Here's a minimal Python/Flask example:

```python
from flask import Flask, request, jsonify
from functools import wraps
import jwt
import secrets

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your-secret-key'  # Change this!

# Mock database (use real database in production)
users = {}
cookies = {}
oauth_codes = {}

def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        if not token:
            return jsonify({"error": "No token provided"}), 401
        try:
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            request.user_id = data['user_id']
        except:
            return jsonify({"error": "Invalid token"}), 401
        return f(*args, **kwargs)
    return decorated

@app.route('/oauth/authorize')
def authorize():
    client_id = request.args.get('client_id')
    redirect_uri = request.args.get('redirect_uri')
    state = request.args.get('state')
    
    # In production: show login page, authenticate user
    # For testing: auto-generate code
    code = secrets.token_urlsafe(32)
    user_id = "test_user"
    oauth_codes[code] = user_id
    
    return f"""
    <html>
        <body>
            <h1>Authorize The Algorithm</h1>
            <p>Grant access to your account?</p>
            <a href="{redirect_uri}?code={code}&state={state}">Authorize</a>
        </body>
    </html>
    """

@app.route('/oauth/token', methods=['POST'])
def token():
    code = request.form.get('code')
    user_id = oauth_codes.get(code)
    
    if not user_id:
        return jsonify({"error": "Invalid code"}), 400
    
    # Generate access token
    access_token = jwt.encode(
        {'user_id': user_id},
        app.config['SECRET_KEY'],
        algorithm='HS256'
    )
    
    del oauth_codes[code]  # One-time use
    
    return jsonify({
        "access_token": access_token,
        "token_type": "Bearer",
        "expires_in": 3600
    })

@app.route('/api/store-cookies', methods=['POST'])
@require_auth
def store_cookies():
    user_cookies = request.json.get('cookies', [])
    cookies[request.user_id] = user_cookies
    return jsonify({"success": True})

@app.route('/api/send-message', methods=['POST'])
@require_auth
def send_message():
    message = request.json.get('message')
    user_cookies = cookies.get(request.user_id)
    
    if not user_cookies:
        return jsonify({"error": "No cookies stored"}), 400
    
    # TODO: Use cookies to send message via X API
    print(f"Sending message: {message}")
    
    return jsonify({"success": True})

@app.route('/api/health')
def health():
    return jsonify({"status": "healthy", "version": "1.0.0"})

if __name__ == '__main__':
    # Use production WSGI server in production (gunicorn, uwsgi)
    app.run(ssl_context='adhoc')  # Requires pyOpenSSL
```

Install dependencies:
```bash
pip install flask pyjwt pyopenssl
```

## 📝 Summary Checklist

### Before Testing
- [ ] Xcode installed on macOS
- [ ] OAuth client ID obtained
- [ ] Client ID added to `AuthenticationManager.swift`
- [ ] Backend OAuth endpoints implemented
- [ ] Backend API endpoints implemented
- [ ] Backend running on HTTPS

### Before App Store Submission
- [ ] Apple Developer account ($99/year)
- [ ] Bundle identifier configured
- [ ] App icon added (all sizes)
- [ ] Privacy policy created and hosted
- [ ] App Store listing completed
- [ ] Screenshots prepared
- [ ] Backend in production with monitoring
- [ ] Rate limiting implemented
- [ ] Security audit completed
- [ ] Test with real users (TestFlight)

## 🆘 Need Help?

If you're missing any requirements:

1. **No macOS/Xcode?**
   - You need a Mac to develop iOS apps
   - Alternative: Use a cloud Mac service (MacStadium, MacinCloud)

2. **Backend not ready?**
   - Use the example code above to get started
   - Deploy to Heroku, AWS, or your preferred platform

3. **No OAuth implementation?**
   - Use a library: `authlib` (Python), `passport` (Node.js)
   - Or implement from scratch using OAuth 2.0 spec

4. **Need SSL certificate?**
   - Use [Let's Encrypt](https://letsencrypt.org/) (free)
   - Or Cloudflare (free tier includes SSL)

---

**Questions?** Check the SETUP_GUIDE.md for detailed instructions on each step.

