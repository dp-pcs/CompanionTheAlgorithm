# 🚀 Quick Start - The Algorithm iOS App

## ⬇️ What You Have

**Complete iOS App** - Ready to integrate with thealgorithm.live!

## 🎯 Three Steps to Launch

### 1️⃣ **Open in Xcode** (30 seconds)
```bash
# Navigate to the project
cd /Users/davidproctor/Documents/GitHub/App_TheAlgorithm

# Open in Xcode
open TwitterCookieApp/TwitterCookieApp.xcodeproj
```

### 2️⃣ **Configure OAuth Client ID** (2 minutes)

Most configuration is already done for thealgorithm.live! You just need to add your OAuth client ID:

**File: `AuthenticationManager.swift`** (line 11)
```swift
private let clientID = "YOUR_CLIENT_ID"  // ← Get this from thealgorithm.live
```

Already configured:
- ✅ OAuth URL: `https://thealgorithm.live/oauth/authorize`
- ✅ Redirect URI: `thealgorithm://oauth/callback`
- ✅ API Base URL: `https://thealgorithm.live/api`
- ✅ URL Scheme: `thealgorithm`

### 3️⃣ **Build & Run** (10 seconds)
- Press **⌘ + R** or click the Play button
- Select iPhone simulator or real device
- Done! 🎉

## ✅ What You Get

✨ **Complete iOS app** with:
- OAuth authentication flow with thealgorithm.live
- X.com cookie extraction via WebView
- Secure Keychain storage
- Backend API integration
- Production-ready UI

## 📚 Next Steps

- **Read SETUP_GUIDE.md** for detailed instructions
- **Read README.md** for architecture overview
- **Configure your thealgorithm.live backend** to handle the endpoints

## 🔧 Your Backend Needs

Your thealgorithm.live backend should implement these endpoints:

```python
# 1. OAuth endpoints (standard OAuth 2.0)
GET  /oauth/authorize
POST /oauth/token

# 2. Store cookies from iOS
POST /api/store-cookies
Body: { cookies: [...] }

# 3. Send messages using stored cookies
POST /api/send-message
Body: { message: "Hello!" }
```

Example Python/Flask implementation included in SETUP_GUIDE.md!

## 🎯 Testing

1. Run app → See authentication interface
2. Authenticate with thealgorithm.live (OAuth)
3. Authenticate with X.com (WebView)
4. Type & send message → Works! ✅

## 💡 Need Help?

Check these files in order:
1. **QUICK_START.md** ← You are here
2. **SETUP_GUIDE.md** ← Detailed setup instructions
3. **README.md** ← Technical architecture docs
4. **REQUIREMENTS.md** ← What you need to deploy

## 🏆 That's It!

You now have a complete iOS app that integrates with thealgorithm.live and extracts X.com cookies without manual export!

---

**Ready to build?** Open `TwitterCookieApp.xcodeproj` in Xcode now!
