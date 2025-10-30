# Setup Guide - The Algorithm iOS App

## 📦 What You Have

This is a complete, production-ready iOS application that integrates with [thealgorithm.live](https://thealgorithm.live) and handles X.com session cookie extraction.

## 🚀 Quick Start (5 Minutes)

### Step 1: Open in Xcode

1. **Navigate to** the project folder
2. **Double-click** `TwitterCookieApp.xcodeproj`
3. Xcode will open the project

### Step 2: Configuration Already Done

The app is already pre-configured for thealgorithm.live:

#### A. OAuth Configuration ✅

**File:** `TwitterCookieApp/AuthenticationManager.swift`  
**Lines:** 9-11

```swift
private let oauthURL = "https://thealgorithm.live/oauth/authorize"
private let redirectURI = "thealgorithm://oauth/callback"
private let clientID = "your_client_id"  // ← UPDATE THIS
```

**You need to:** Get your OAuth client ID from thealgorithm.live

#### B. API Base URL ✅

**File:** `TwitterCookieApp/APIClient.swift`  
**Line:** 7

```swift
private let baseURL = "https://thealgorithm.live/api"
```

**Already configured!** No changes needed unless you have a different API endpoint.

#### C. URL Scheme ✅

**File:** `TwitterCookieApp/Info.plist`  

```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>thealgorithm</string>
</array>
```

**Already configured!** Matches the redirect URI `thealgorithm://oauth/callback`

### Step 3: Build & Run

1. **Select a target device** (iPhone simulator or real device)
2. **Press ⌘ + R** or click the **Play** button
3. The app will build and launch!

## 🔧 Backend Integration

Your thealgorithm.live backend needs to implement these endpoints:

### Required Endpoints

#### 1. OAuth Authorization
```
GET /oauth/authorize
Parameters: client_id, redirect_uri, response_type, scope, state
Returns: Authorization code
```

#### 2. Token Exchange
```
POST /oauth/token
Body: {
  grant_type: "authorization_code",
  client_id: "...",
  code: "...",
  redirect_uri: "thealgorithm://oauth/callback"
}
Returns: { access_token: "..." }
```

#### 3. Store Cookies
```
POST /api/store-cookies
Headers: Authorization: Bearer <token>
Body: {
  cookies: [
    {
      name: "auth_token",
      value: "...",
      domain: "x.com",
      path: "/",
      expires: 1234567890,
      httpOnly: true,
      secure: true
    }
  ],
  timestamp: 1234567890
}
Returns: { success: true }
```

#### 4. Send Message
```
POST /api/send-message
Headers: Authorization: Bearer <token>
Body: {
  message: "Hello from iOS!",
  timestamp: 1234567890
}
Returns: { success: true }
```

### Python Backend Example

```python
from flask import Flask, request, jsonify
import json

app = Flask(__name__)

# Store user cookies (use database in production)
user_cookies = {}

@app.route('/api/store-cookies', methods=['POST'])
def store_cookies():
    # Get user from OAuth token
    token = request.headers.get('Authorization').replace('Bearer ', '')
    user_id = validate_token(token)  # Implement your token validation
    
    # Store cookies
    cookies = request.json['cookies']
    user_cookies[user_id] = cookies
    
    return jsonify({"success": True})

@app.route('/api/send-message', methods=['POST'])
def send_message():
    # Get user from OAuth token
    token = request.headers.get('Authorization').replace('Bearer ', '')
    user_id = validate_token(token)
    
    # Get stored cookies
    cookies = user_cookies.get(user_id)
    if not cookies:
        return jsonify({"error": "No cookies found"}), 400
    
    # Use your API client with stored cookies
    message = request.json['message']
    # Implement your message sending logic here
    
    return jsonify({"success": True})

if __name__ == '__main__':
    app.run(debug=True)
```

## 🎯 Testing the App

### Test Flow Checklist

1. ✅ **Launch App** - Should see "The Algorithm" interface
2. ✅ **Tap "Authenticate with Your Service"** - Should redirect to OAuth
3. ✅ **Complete OAuth** - Should return to app with success message
4. ✅ **Tap "Authenticate with X.com"** - WebView opens with X.com login
5. ✅ **Login to X.com** - Enter credentials, complete login
6. ✅ **Auto Cookie Extraction** - Should dismiss WebView and show success
7. ✅ **Type Message** - Message field should now be enabled
8. ✅ **Send Message** - Should send through your backend successfully

### Debugging Tips

**OAuth Not Working?**
- Check URL scheme `thealgorithm` matches in Info.plist and redirect URI
- Verify thealgorithm.live OAuth has correct redirect URI registered
- Check console logs for redirect URL

**Cookies Not Extracted?**
- Make sure user completes full X.com login (reaches home timeline)
- Check console for cookie names extracted
- Verify WebView loads x.com correctly

**API Calls Failing?**
- Verify thealgorithm.live backend is running and reachable
- Check backend logs for request details
- Ensure OAuth token is being sent correctly

**Build Errors?**
- Clean build folder: Product → Clean Build Folder (⌘ + Shift + K)
- Update to latest Xcode if needed
- Check all files are included in target

## 📱 Device Testing

### Running on Real Device

1. **Connect iPhone via USB**
2. **Select your device** in Xcode's device menu
3. **Add Apple ID** to Xcode (Preferences → Accounts)
4. **Select your team** in project settings
5. **Build & Run** (⌘ + R)

Note: Free Apple Developer accounts can test on device for 7 days before needing to rebuild.

### TestFlight (Beta Testing)

1. **Archive app**: Product → Archive
2. **Upload to App Store Connect**
3. **Create TestFlight beta**
4. **Invite testers via email**

## 🔒 Security Checklist

Before deploying to production:

- ✅ **Use HTTPS** for all API endpoints (already configured)
- ✅ **Validate OAuth state** parameter (CSRF protection)
- ✅ **Secure cookie storage** (already using Keychain ✓)
- ✅ **Token expiration** - Implement refresh token logic
- ✅ **Rate limiting** on backend endpoints
- ✅ **Input validation** for message content
- ✅ **Error logging** without exposing sensitive data

## 🚢 Production Deployment

### App Store Submission

1. **Update Bundle Identifier** in Xcode (e.g., `live.thealgorithm.ios`)
2. **Add App Icon** in Assets.xcassets
3. **Create App Store Connect listing**
4. **Archive & upload** build
5. **Complete metadata** (screenshots, description)
6. **Submit for review**

### Backend Deployment

1. **Ensure thealgorithm.live** has all required endpoints
2. **Enable SSL/TLS** for all endpoints (should already be done)
3. **Set up monitoring** and logging
4. **Configure CORS** if needed
5. **Test OAuth flow** end-to-end

## 📖 File Structure

```
App_TheAlgorithm/
├── TwitterCookieApp.xcodeproj/     # Xcode project file
│   └── project.pbxproj              # Project configuration
├── TwitterCookieApp/                # Source code
│   ├── AppDelegate.swift            # App lifecycle
│   ├── SceneDelegate.swift          # Scene lifecycle
│   ├── ViewController.swift         # Main UI controller
│   ├── AuthenticationManager.swift  # OAuth + X.com auth
│   ├── CookieManager.swift          # Cookie storage/validation
│   ├── APIClient.swift              # Backend communication
│   ├── Info.plist                   # App configuration
│   ├── Assets.xcassets/             # Images & colors
│   └── Base.lproj/
│       ├── Main.storyboard          # UI layout
│       └── LaunchScreen.storyboard  # Launch screen
├── README.md                        # Project documentation
├── SETUP_GUIDE.md                   # This file
└── QUICK_START.md                   # Quick start guide
```

## 🆘 Getting Help

### Common Issues

**"No such module" error**
- Clean build folder (⌘ + Shift + K)
- Restart Xcode

**Signing errors**
- Add Apple ID in Xcode → Preferences → Accounts
- Select team in project settings

**WebView blank/not loading**
- Check internet connection
- Verify URL is correct (https://x.com/login)
- Check console for network errors

**Cookies not persisting**
- Verify Keychain entitlements
- Check device has passcode enabled
- Review console logs for storage errors

### Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [WKWebView Guide](https://developer.apple.com/documentation/webkit/wkwebview)
- [OAuth 2.0 Spec](https://oauth.net/2/)
- [iOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)

## ✅ Success Checklist

Before considering setup complete:

- [ ] Project opens in Xcode without errors
- [ ] OAuth client ID configured in AuthenticationManager.swift
- [ ] App builds successfully
- [ ] thealgorithm.live backend has required endpoints
- [ ] OAuth authentication completes
- [ ] X.com WebView loads and accepts login
- [ ] Cookies extracted and stored
- [ ] Backend receives cookies successfully
- [ ] Message sending works end-to-end

## 🎉 You're Done!

Your iOS app is now ready to integrate with thealgorithm.live. Users can authenticate directly from their iPhones!

---

**Need More Help?** Check the inline code comments for detailed explanations of each component.
