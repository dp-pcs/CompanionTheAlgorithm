# Mobile App - Backend Integration Requirements

**For Backend Team**  
**Date:** October 31, 2025

---

## ✅ What Mobile App Needs

### 1. API Key Status Check (After Login)

**Endpoint:** `GET /api/api-key-status`  
**When:** Called immediately after user logs in  
**Purpose:** Determine if user can use LLM features

**Response:**
```json
{
  "using_system_keys": true,          // Pro/Pro+ users
  "needs_own_keys": false,            // Starter users need to add keys
  "available_providers": ["openai"]   // Which LLM providers are configured
}
```

**Mobile App Logic:**
- `using_system_keys = true` → Enable all LLM features (user is Pro/Pro+)
- `needs_own_keys = true` AND `available_providers = []` → Show "Add API Keys" screen
- `needs_own_keys = true` AND `available_providers = ["openai"]` → Enable LLM features

### 2. Save User Keys (Starter Tier)

**Endpoint:** `POST /api/v1/settings/llm-keys` (already exists)  
**When:** User enters their own API keys  
**Format:**
```json
{
  "openai": "sk-...",
  "anthropic": "sk-ant-...",
  "google": "AIza..."
}
```

**Backend Should:**
- Encrypt and save to `User.llm_api_key` field
- Return success/error
- Keys automatically available for next API call

### 3. Automatic Key Selection

**When user calls any LLM endpoint** (e.g., `POST /api/v1/replies/bulk-generate-and-queue`):
- Backend automatically selects correct keys:
  - **Pro/Pro+** → Use system environment keys
  - **Starter** → Use user's saved keys from database
- Mobile app doesn't need to send keys
- Mobile app doesn't need to know which keys to use

---

## 🐛 Current Issue

**Problem:** Users who save keys via Settings page cannot generate replies (returns "0 of 15")

**Root Cause:** Middleware only loads keys from `SystemIntegrationConfig` table, not from `User.llm_api_key` field

**File:** `app/middleware/user_context.py` → `_load_credentials()` function

**Fix Needed:** Update middleware to also load keys from `User.llm_api_key` and merge with existing credentials

**Details:** See `BACKEND_API_KEY_BUG.md` for complete fix

---

## 📱 Mobile App Flow

```
User Opens App
     ↓
User Logs In (OAuth)
     ↓
App Calls: GET /api/api-key-status
     ↓
┌────────────────┬─────────────────┐
│ Pro/Pro+ User  │  Starter User   │
│ (system keys)  │  (own keys)     │
└────────────────┴─────────────────┘
         ↓                 ↓
    Enable All        Has keys?
    Features          ├─ Yes → Enable
                      └─ No  → Show "Add Keys"
                                    ↓
                          POST /api/v1/settings/llm-keys
                                    ↓
                              Enable Features
```

---

## 🎯 Key Points for Backend Team

1. **Mobile app does NOT store keys locally** (security)
2. **Mobile app does NOT pass keys in requests** (backend handles it)
3. **Backend automatically selects keys** based on user tier
4. **Fix the middleware** to load keys from both locations:
   - `SystemIntegrationConfig` table (existing)
   - `User.llm_api_key` field (missing)

---

## 📚 Full Documentation

- **API Specification:** `API_IOS_SPECIFICATION.md`
- **Key Management Guide:** `apikeymgmt.md`
- **Bug Details:** `BACKEND_API_KEY_BUG.md`

---

## ✅ Testing Checklist

- [ ] Starter user can save keys via Settings
- [ ] Keys are encrypted in `users.llm_api_key`
- [ ] Middleware loads keys from both locations
- [ ] Reply generation works (not 0 of 15)
- [ ] Mobile app can call `/api/api-key-status`
- [ ] Mobile app can call `/api/v1/settings/llm-keys`
- [ ] Pro users still get system keys automatically

---

**Priority:** HIGH (blocks mobile app LLM features)  
**Backend Files to Update:** `app/middleware/user_context.py`  
**Mobile Status:** Ready and waiting for backend fix

