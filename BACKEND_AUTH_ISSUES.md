# Backend Authentication Issues - Mobile App

## 🔴 Critical Issues

### Issue 1: Cookie Storage Endpoint Python Error

**Endpoint**: `POST /api/store-cookies`

**Error**:
```
Failed to store cookies: cannot access local variable 'datetime' where it is not associated with a value
```

**Impact**: 
- Mobile app successfully authenticates with X.com and extracts cookies
- Cookies are stored locally in iOS Keychain ✅
- Cookies FAIL to be sent to backend ❌
- This causes all endpoints requiring session cookies to return 401

**Likely Cause**:
- Missing `from datetime import datetime` import in Python backend
- Or using `datetime` variable name that shadows the module

**Expected Behavior**:
```python
from datetime import datetime

# When receiving cookies from mobile app:
expires_timestamp = cookie_data.get("expires", 0)
expires_date = datetime.fromtimestamp(expires_timestamp)
```

---

### Issue 2: `/api/v1/replies` Endpoint Returns 401 Despite Valid OAuth Token

**Endpoint**: `GET /api/v1/replies?status=generated`

**Behavior**:
- ✅ Mobile app sends valid OAuth Bearer token (same token that works for other endpoints)
- ✅ `/api/v1/users/monitoring/status` works with OAuth token
- ✅ `/api/v1/replies/bulk-generate-and-queue` works with OAuth token
- ❌ `/api/v1/replies` returns 401 with OAuth token

**Response**:
```json
{
  "detail": "Authentication required (session or token)"
}
```

**Impact**:
- Reply Queue view shows "unauthorized" error
- Queue badge count shows 0
- Users cannot see their generated replies

**Likely Cause**:
- The GET `/api/v1/replies` endpoint has different authentication middleware than other endpoints
- It may require BOTH OAuth token AND session cookies, but because cookie storage failed (Issue #1), no session exists on backend

**Workaround**:
- Fix Issue #1 first (cookie storage Python error)
- OR update `/api/v1/replies` endpoint to accept OAuth token alone (consistent with other endpoints)

---

### Issue 3: TwiKit Security Error

**Endpoint**: `POST /api/v1/replies/twikit/like-tweets-bulk`

**Error**:
```json
{
  "detail": "Failed to bulk like tweets: SECURITY ERROR: TwiKit operation attempted without user context. This would cause cross-account authentication leakage. Ensure middleware is properly setting current_user_id."
}
```

**Impact**:
- Mobile app cannot bulk like tweets
- Middleware is not properly setting `current_user_id` for TwiKit operations

**Likely Cause**:
- Middleware that sets `current_user_id` is not running for this endpoint
- OR the middleware runs but fails to extract user ID from OAuth token

**Required Fix**:
Ensure middleware extracts user ID from OAuth token JWT and sets it in request context BEFORE TwiKit operations.

---

## 📋 Mobile App Logs

### Successful Flow:
```
✅ Successfully obtained OAuth access token
✅ Stored 4 cookies securely (auth_token, ct0, twid, kdt)
```

### Failed Cookie Storage:
```
⚠️ Warning: Failed to send cookies to backend: Failed to store cookies: cannot access local variable 'datetime' where it is not associated with a value
```

### Failed API Calls After Cookie Storage Failure:
```
🌐 [API] GET https://thealgorithm.live/api/v1/replies?status=generated
   ↳ bearer token prefix: eyJhbG… (length: 309)
⚠️ [API] 401 response body: {"detail":"Authentication required (session or token)"}
```

---

## 🔧 Recommended Backend Fixes

### Priority 1: Fix Cookie Storage Python Error
```python
# File: app/api/v1/endpoints/cookies.py (or similar)

from datetime import datetime  # ← ADD THIS IMPORT

@router.post("/api/store-cookies")
async def store_cookies(cookies: list[dict], current_user: User = Depends(get_current_user)):
    for cookie in cookies:
        expires_timestamp = cookie.get("expires", 0)
        expires_date = datetime.fromtimestamp(expires_timestamp)  # ← Should work now
        # ... rest of storage logic
```

### Priority 2: Make `/api/v1/replies` Authentication Consistent
Option A: Accept OAuth token alone (recommended for API consistency)
```python
# File: app/api/v1/endpoints/replies.py

@router.get("/api/v1/replies")
async def get_replies(
    status: str = "generated",
    current_user: User = Depends(get_current_user_oauth)  # ← Use OAuth dependency
):
    # ... endpoint logic
```

Option B: Clearly document that endpoint requires both OAuth + cookies
- Update `API_IOS_SPECIFICATION.md`
- Ensure mobile app waits for successful cookie storage before calling this endpoint

### Priority 3: Fix TwiKit Middleware
```python
# File: app/middleware/user_context.py or app/middleware/twikit.py

# Ensure this middleware runs for all TwiKit routes
@app.middleware("http")
async def set_user_context(request: Request, call_next):
    if request.url.path.startswith("/api/v1/replies/twikit"):
        # Extract user_id from OAuth token
        token = request.headers.get("Authorization", "").replace("Bearer ", "")
        payload = decode_jwt(token)
        user_id = payload.get("sub")
        
        # Set in context for TwiKit
        current_user_id.set(user_id)  # ← Must be set before TwiKit operations
    
    response = await call_next(request)
    return response
```

---

## ✅ Expected Mobile App Behavior After Fixes

1. User completes OAuth flow → gets access token ✅
2. User logs into X.com in WebView → cookies extracted ✅
3. Cookies sent to backend `/api/store-cookies` → **should succeed** (currently fails)
4. Mobile app calls `/api/v1/replies?status=generated` → **should return replies** (currently 401)
5. Queue badge shows correct count → **should work** (currently shows 0)
6. Bulk like tweets → **should work** (currently security error)

---

## 📱 Mobile App Version Info

- **Repository**: `mobile_thealgorithm`
- **Base URL**: `https://thealgorithm.live`
- **OAuth Client ID**: `ios_app_081b7e3ab09f49b2`
- **Date**: 2025-11-01

