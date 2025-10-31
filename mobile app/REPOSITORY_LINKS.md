# 🔗 Repository Links - iOS Mobile App

This document links the backend and iOS mobile app repositories.

---

## 📱 iOS Mobile App Repository

**Repository:** `mobile_thealgorithm`  
**Clone URL:** `git@github.com:dp-pcs/mobile_thealgorithm.git`

**Clone the iOS app:**
```bash
git clone git@github.com:dp-pcs/mobile_thealgorithm.git
cd mobile_thealgorithm
```

**Contents:**
- Swift source code (AuthenticationManager, APIClient, etc.)
- Xcode project (`.xcodeproj`)
- iOS UI implementation (Storyboards, ViewControllers)
- iOS-specific configuration (Info.plist, entitlements)
- App assets (icons, images)

---

## 🖥️ Backend Repository

**Repository:** `thealgorithm`  
**Clone URL:** `git@github.com:dp-pcs/thealgorithm.git`  
**Web:** `https://github.com/dp-pcs/thealgorithm`

**Clone the backend:**
```bash
git clone git@github.com:dp-pcs/thealgorithm.git
cd thealgorithm
```

**Contents:**
- FastAPI backend (Python)
- OAuth 2.0 Provider implementation
- iOS API endpoints (`/api/store-cookies`, `/api/send-message`)
- Database models and migrations
- API documentation

---

## 📋 Integration Documentation

### Shared API Contract

Both repositories follow this shared specification:

**Primary Reference:**
- 📄 [IOS_API_SPECIFICATION.md](../docs/api/IOS_API_SPECIFICATION.md)
  - Complete API contract
  - Request/response schemas
  - Authentication flow
  - Error codes

**Location in repositories:**
```
Backend: thealgorithm/docs/api/IOS_API_SPECIFICATION.md
iOS:     mobile_thealgorithm/docs/API_INTEGRATION.md (should link to backend)
```

### For iOS Developers

**Start with these backend docs:**
1. [IOS_TEAM_HANDOFF.md](./IOS_TEAM_HANDOFF.md) - Setup instructions
2. [IOS_API_SPECIFICATION.md](../docs/api/IOS_API_SPECIFICATION.md) - API reference
3. [BACKEND_INTEGRATION_COMPLETE.md](./BACKEND_INTEGRATION_COMPLETE.md) - What's implemented

**Backend endpoints you'll integrate with:**
- `GET /oauth/authorize` - OAuth authorization
- `POST /oauth/token` - Token exchange
- `POST /api/store-cookies` - Store X.com cookies
- `POST /api/send-message` - Post tweets
- `GET /api/health` - Health check

### For Backend Developers

**When iOS team needs help:**
1. Review [IOS_API_SPECIFICATION.md](../docs/api/IOS_API_SPECIFICATION.md)
2. Check implementation in `app/api/v1/endpoints/ios_app.py`
3. Check OAuth provider in `app/api/v1/endpoints/oauth_provider.py`
4. Review database models in `app/models/oauth_provider.py`

**To register iOS OAuth client:**
```bash
cd thealgorithm
python scripts/register_ios_oauth_client.py
```

---

## 🔄 Development Workflow

### Initial Setup

**Step 1: Backend Setup**
```bash
# Clone backend
git clone git@github.com:dp-pcs/thealgorithm.git
cd thealgorithm

# Follow setup instructions
# Backend will be running at: https://thealgorithm.live
```

**Step 2: iOS Setup**
```bash
# Clone iOS app
git clone git@github.com:dp-pcs/mobile_thealgorithm.git
cd mobile_thealgorithm

# Open in Xcode
open TheAlgorithm.xcodeproj
```

**Step 3: Register OAuth Client**
```bash
# From backend repo
cd thealgorithm
python scripts/register_ios_oauth_client.py
# Copy the generated client_id
```

**Step 4: Configure iOS App**
```swift
// In mobile_thealgorithm/AuthenticationManager.swift
private let clientID = "ios_app_abc123..."  // Paste client_id from Step 3
```

### Making Changes

**If you change the API contract:**
1. Update `thealgorithm/docs/api/IOS_API_SPECIFICATION.md`
2. Update backend implementation in `thealgorithm/app/api/v1/endpoints/ios_app.py`
3. Create GitHub issue in iOS repo about API change
4. Coordinate with iOS team before deploying

**If iOS needs a new endpoint:**
1. iOS team creates issue in backend repo
2. Backend team reviews and implements
3. Update `IOS_API_SPECIFICATION.md`
4. Deploy to staging for iOS testing
5. iOS team updates their app
6. Test end-to-end
7. Deploy to production

---

## 🧪 Testing Integration

### Backend Testing

**Test OAuth provider:**
```bash
# Health check
curl https://thealgorithm.live/api/health

# Should return:
# {"status": "healthy", "version": "1.0.0", "timestamp": ...}
```

**Test with iOS app:**
- Monitor backend logs: `tail -f logs/api.log`
- Watch for iOS app requests
- Check for errors or issues

### iOS Testing

**Test against backend:**
1. Start with staging/dev backend
2. Test OAuth flow
3. Test cookie storage
4. Test message posting
5. Move to production when stable

---

## 📊 Repository Structure

```
Backend Repository (thealgorithm)
├── app/
│   ├── api/v1/endpoints/
│   │   ├── ios_app.py              ← iOS-specific endpoints
│   │   └── oauth_provider.py       ← OAuth provider
│   ├── models/
│   │   └── oauth_provider.py       ← OAuth database models
│   └── services/
│       └── oauth_provider_service.py ← OAuth business logic
├── docs/
│   └── api/
│       └── IOS_API_SPECIFICATION.md ← API contract (source of truth)
├── mobile app/                      ← Documentation for iOS
│   ├── IOS_TEAM_HANDOFF.md         ← iOS setup guide
│   ├── REPOSITORY_LINKS.md         ← This file
│   └── ...
└── scripts/
    └── register_ios_oauth_client.py ← Register iOS app

iOS Repository (mobile_thealgorithm)
├── TheAlgorithm/
│   ├── AuthenticationManager.swift  ← OAuth & X.com auth
│   ├── APIClient.swift              ← Backend communication
│   ├── CookieManager.swift          ← Cookie management
│   └── ViewController.swift         ← UI
├── TheAlgorithm.xcodeproj/          ← Xcode project
├── docs/
│   └── API_INTEGRATION.md           ← Links to backend API spec
└── README.md                        ← Points to backend docs
```

---

## 🔐 Access & Permissions

**Backend Repository:**
- Public/Private: [Check GitHub]
- Write access: Backend team
- Read access: iOS team (minimum)

**iOS Repository:**
- Public/Private: [Check GitHub]
- Write access: iOS team
- Read access: Backend team (for support)

---

## 📝 Issue Tracking

**API Contract Issues:**
- Create in: Backend repo with `mobile-api` label
- Assign to: Both teams (coordinate)

**Backend Issues:**
- Create in: Backend repo
- Examples: OAuth bugs, endpoint errors, server issues

**iOS Issues:**
- Create in: iOS repo
- Examples: UI bugs, authentication issues, client-side errors

**Integration Issues:**
- Create in: Both repos (cross-link)
- Examples: End-to-end flow problems, data format issues

---

## 🚀 Deployment

**Backend Deployment:**
- Production: https://thealgorithm.live
- Staging: [Add if available]
- Deploy command: [Add your deploy process]

**iOS Deployment:**
- TestFlight: [Add when available]
- App Store: [Add when available]
- Build process: Xcode Cloud or manual

---

## 📞 Quick Contact

**Need Backend Help?**
- Backend repo: https://github.com/dp-pcs/thealgorithm
- Create issue with `mobile-api` label

**Need iOS Help?**
- iOS repo: git@github.com:dp-pcs/mobile_thealgorithm.git
- Create issue in iOS repo

**Need Both Teams?**
- Create issue in backend repo
- Tag with `mobile-api` and `needs-ios-team`
- Cross-link to iOS repo issue

---

**Last Updated:** October 31, 2025  
**Backend Repo:** git@github.com:dp-pcs/thealgorithm.git  
**iOS Repo:** git@github.com:dp-pcs/mobile_thealgorithm.git

