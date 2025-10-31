# 🎯 START HERE - iOS Mobile App Integration

**For:** iOS Development Team  
**Date:** October 31, 2025  
**Status:** Backend Ready ✅

---

## 📱 Quick Overview

Your **backend is 100% ready** for iOS integration. The iOS app code lives in a **separate repository**.

**iOS Repository:** `git@github.com:dp-pcs/mobile_thealgorithm.git`  
**Backend Repository:** `git@github.com:dp-pcs/thealgorithm.git` (this repo)

---

## 🚀 Get Started in 3 Steps

### Step 1: Read the Handoff Document (10 minutes)

📄 **[IOS_TEAM_HANDOFF.md](./IOS_TEAM_HANDOFF.md)**

This tells you everything you need to know:
- What's ready on the backend
- How to configure your iOS app
- Step-by-step setup instructions
- Testing checklist
- Common issues & solutions

### Step 2: Review the API Specification (15 minutes)

📄 **[IOS_API_SPECIFICATION.md](../docs/api/IOS_API_SPECIFICATION.md)**

This is the API contract:
- Complete endpoint reference
- Request/response examples
- Authentication flow (OAuth 2.0 + PKCE)
- Error codes and handling
- Security requirements

### Step 3: Request OAuth Client Registration (2 minutes)

Contact the backend team and ask them to run:
```bash
python scripts/register_ios_oauth_client.py
```

They'll give you a `client_id` like: `ios_app_abc123def456`

---

## ✅ What Backend Has Ready for You

**OAuth 2.0 Provider:**
- `GET /oauth/authorize` - Authorization (step 1)
- `POST /oauth/token` - Token exchange (step 2)
- PKCE security (no client secrets needed)
- JWT token validation
- 24-hour token expiration

**iOS-Specific APIs:**
- `POST /api/store-cookies` - Store X.com session cookies
- `POST /api/send-message` - Post tweets using stored cookies
- `GET /api/health` - Health check (no auth required)

**Security:**
- ✅ PKCE flow for mobile apps
- ✅ JWT signing & validation
- ✅ Cookie encryption at rest
- ✅ HTTPS enforcement
- ✅ Subscription verification

---

## 🔧 Configuration You'll Need

**Update your iOS app with these values:**

```swift
// AuthenticationManager.swift (or equivalent)
private let oauthURL = "https://thealgorithm.live/oauth/authorize"
private let tokenURL = "https://thealgorithm.live/oauth/token"
private let clientID = "YOUR_CLIENT_ID_HERE"  // From Step 3
private let redirectURI = "thealgorithm://oauth/callback"
private let baseURL = "https://thealgorithm.live/api"
private let usePKCE = true  // REQUIRED
```

**Info.plist URL Scheme:**
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

---

## 🧪 Test Backend Connectivity

**Try this first (no auth required):**

```bash
curl https://thealgorithm.live/api/health
```

**Expected response:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": 1735689600
}
```

**Or in Swift:**
```swift
let url = URL(string: "https://thealgorithm.live/api/health")!
URLSession.shared.dataTask(with: url) { data, response, error in
    if let data = data {
        print(String(data: data, encoding: .utf8)!)
    }
}.resume()
```

---

## 📚 All Documentation

**Essential (Read These):**
1. 🔴 [IOS_TEAM_HANDOFF.md](./IOS_TEAM_HANDOFF.md) - Setup guide
2. 🔴 [IOS_API_SPECIFICATION.md](../docs/api/IOS_API_SPECIFICATION.md) - API contract

**Reference (For Details):**
3. 🟡 [BACKEND_INTEGRATION_COMPLETE.md](./BACKEND_INTEGRATION_COMPLETE.md) - What's implemented
4. 🟡 [REPOSITORY_LINKS.md](./REPOSITORY_LINKS.md) - Cross-repo workflow
5. 🟢 [README_FOR_IOS_REPO.md](./README_FOR_IOS_REPO.md) - Copy to iOS repo

---

## 🎯 Expected Authentication Flow

```
1. User opens iOS app
   ↓
2. Taps "Login" button
   ↓
3. App opens OAuth web view
   → https://thealgorithm.live/oauth/authorize?client_id=...&code_challenge=...
   ↓
4. User logs in with X OAuth on web
   ↓
5. Backend redirects to: thealgorithm://oauth/callback?code=xxx
   ↓
6. App captures code
   ↓
7. App exchanges code for token
   → POST /oauth/token with code_verifier
   ↓
8. Backend returns access token
   ↓
9. App stores token in Keychain
   ↓
10. User authenticated! ✅
    ↓
11. User taps "Connect X Account"
    ↓
12. App opens X.com WebView
    ↓
13. User logs into X.com
    ↓
14. App extracts cookies from WebView
    ↓
15. App sends to: POST /api/store-cookies
    ↓
16. Backend stores cookies securely
    ↓
17. User can now post tweets! ✅
    ↓
18. User types message, taps "Post"
    ↓
19. App sends to: POST /api/send-message
    ↓
20. Backend posts tweet using stored cookies
    ↓
21. Tweet appears on X.com! 🎉
```

---

## 🚨 Common Questions

**Q: Where is the iOS app code?**  
A: In a separate repo: `git@github.com:dp-pcs/mobile_thealgorithm.git`

**Q: What client_id should I use?**  
A: Contact backend team to register your app and get a client_id

**Q: Do I need a client_secret?**  
A: No! Mobile apps use PKCE instead (more secure)

**Q: What cookies do I need to extract?**  
A: Required: `auth_token`, `ct0`. Optional but helpful: `auth_multi`, `twid`

**Q: How long do tokens last?**  
A: Access tokens expire in 24 hours. You'll need to re-authenticate after that.

**Q: What if user's subscription expired?**  
A: Backend returns `402 Payment Required`. Show upgrade screen to user.

---

## 📞 Need Help?

**Backend Questions:**
- Create issue: https://github.com/dp-pcs/thealgorithm/issues
- Label: `mobile-api`

**Can't Find Something?**
- Check [IOS_TEAM_HANDOFF.md](./IOS_TEAM_HANDOFF.md) first
- Check [IOS_API_SPECIFICATION.md](../docs/api/IOS_API_SPECIFICATION.md)
- Then create GitHub issue

**Integration Problems?**
- Check backend logs
- Verify your configuration matches examples
- Ensure OAuth client is registered
- Create issue with full error details

---

## ✅ Quick Checklist

Before you start coding:
- [ ] Read IOS_TEAM_HANDOFF.md
- [ ] Read IOS_API_SPECIFICATION.md  
- [ ] Test `/api/health` endpoint
- [ ] Request OAuth client registration
- [ ] Receive client_id from backend team

Ready to implement:
- [ ] Update iOS app configuration
- [ ] Implement PKCE flow
- [ ] Implement OAuth authorization
- [ ] Implement token exchange
- [ ] Implement cookie extraction
- [ ] Implement API calls
- [ ] Test end-to-end

---

**🎉 Your backend is waiting for you! Everything is ready.**

**Next:** Read [IOS_TEAM_HANDOFF.md](./IOS_TEAM_HANDOFF.md) to get started.

---

**iOS Repository:** git@github.com:dp-pcs/mobile_thealgorithm.git  
**Backend Repository:** git@github.com:dp-pcs/thealgorithm.git  
**Last Updated:** October 31, 2025

