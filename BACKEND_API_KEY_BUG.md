# 🐛 CRITICAL: API Key Loading Bug in Middleware

**Status:** 🔴 HIGH PRIORITY - Blocks mobile app LLM features  
**Date:** October 31, 2025  
**Reporter:** Mobile Team  
**Affects:** iOS app, Web app (reply generation)

---

## 📋 Summary

Users who save LLM API keys via the Settings page **cannot use reply generation** because the backend middleware is not loading keys from the correct database location.

**Result:** Users see "Generated 0 of 15 replies" even though they have valid API keys configured.

---

## 🔍 Root Cause

The backend has **two separate places** where LLM API keys can be stored:

### 1. SystemIntegrationConfig Table ✅ (Currently Loaded)
```sql
SELECT openai_api_key, anthropic_api_key, google_api_key 
FROM system_integration_configs 
WHERE name = 'user:{user_id}'
```

**Used for:** System-wide keys, admin keys

### 2. User.llm_api_key Field ❌ (NOT Loaded)
```sql
SELECT llm_api_key 
FROM users 
WHERE id = '{user_id}'
```

**Used for:** Individual user keys (Starter tier BYOK)

**THE PROBLEM:** The Settings page saves to `User.llm_api_key`, but the middleware only checks `SystemIntegrationConfig`!

---

## 📁 Affected Files

### Middleware (Where Keys Are Loaded)
**File:** `app/middleware/user_context.py`  
**Function:** `_load_credentials(user_id)`  
**Lines:** 60-109

**Current Code:**
```python
async def _load_credentials(self, user_id: str) -> Dict[str, str]:
    """Load and decrypt integration credentials for the given user."""
    
    # ✅ Loads from SystemIntegrationConfig
    result = await session.execute(
        select(SystemIntegrationConfig).where(
            SystemIntegrationConfig.name == f"user:{user_id}"
        )
    )
    config = result.scalar_one_or_none()
    
    # ❌ Does NOT load from User.llm_api_key
    
    credentials = {
        "OPENAI_API_KEY": decode(config.openai_api_key),
        "ANTHROPIC_API_KEY": decode(config.anthropic_api_key),
        "GOOGLE_API_KEY": decode(config.google_api_key),
    }
```

### Settings Page (Where Keys Are Saved)
**File:** `app/api/v1/endpoints/settings.py`  
**Endpoint:** `POST /api/v1/settings/llm-keys`  
**Lines:** 123-169

**Current Code:**
```python
@router.post("/llm-keys")
async def save_llm_keys(request: LLMKeysRequest, ...):
    # ✅ Saves to User.llm_api_key (JSON encrypted)
    encrypted = token_security.encrypt_token_data(existing_keys, user_id=current_user.id)
    current_user.llm_api_key = encrypted
    await db.commit()
```

---

## 🎯 The Fix

The middleware needs to **also load keys from `User.llm_api_key`** and merge them with `SystemIntegrationConfig` keys.

### Updated Code for `user_context.py`

```python
async def _load_credentials(self, user_id: str) -> Dict[str, str]:
    """Load and decrypt integration credentials for the given user."""
    
    try:
        async with async_session_factory() as session:
            user = await session.get(User, user_id)
            
            # Load from SystemIntegrationConfig (existing)
            result = await session.execute(
                select(SystemIntegrationConfig).where(
                    SystemIntegrationConfig.name == f"user:{user_id}"
                )
            )
            config = result.scalar_one_or_none()
            
            # Admin fallback (existing)
            if not config and user and getattr(user, "is_admin", False):
                fallback_result = await session.execute(
                    select(SystemIntegrationConfig).where(
                        SystemIntegrationConfig.name == "system"
                    )
                )
                config = fallback_result.scalar_one_or_none()
        
        credentials = {}
        
        # Load from SystemIntegrationConfig
        if config:
            def decode(value: str | None) -> str | None:
                if not value:
                    return None
                try:
                    return decrypt(value)
                except Exception as exc:
                    logger.warning("Failed to decrypt credential for user %s: %s", user_id, exc)
                    return None
            
            credentials = {
                "X_API_KEY": decode(config.x_api_key),
                "X_API_SECRET": decode(config.x_api_secret),
                "X_ACCESS_TOKEN": decode(config.x_access_token),
                "X_ACCESS_TOKEN_SECRET": decode(config.x_access_token_secret),
                "X_BEARER_TOKEN": decode(config.x_bearer_token),
                "OPENAI_API_KEY": decode(config.openai_api_key),
                "ANTHROPIC_API_KEY": decode(config.anthropic_api_key),
                "GOOGLE_API_KEY": decode(config.google_api_key),
            }
            credentials = {k: v for k, v in credentials.items() if v}
        
        # 🆕 ALSO load from User.llm_api_key
        if user and user.llm_api_key:
            try:
                from app.services.oauth_token_security import token_security
                import json
                
                # Decrypt user's stored LLM keys
                user_keys_decrypted = token_security.decrypt_token_data(
                    user.llm_api_key,
                    user_id=user_id,
                    validate_user=False
                )
                
                if isinstance(user_keys_decrypted, dict):
                    # Merge user's LLM keys (user keys take precedence)
                    if "openai" in user_keys_decrypted and user_keys_decrypted["openai"]:
                        credentials["OPENAI_API_KEY"] = user_keys_decrypted["openai"]
                    if "anthropic" in user_keys_decrypted and user_keys_decrypted["anthropic"]:
                        credentials["ANTHROPIC_API_KEY"] = user_keys_decrypted["anthropic"]
                    if "google" in user_keys_decrypted and user_keys_decrypted["google"]:
                        credentials["GOOGLE_API_KEY"] = user_keys_decrypted["google"]
                    
                    logger.info(f"Loaded user LLM keys for user {user_id}")
                
            except Exception as exc:
                logger.warning("Failed to load user LLM keys for user %s: %s", user_id, exc)
        
        return credentials
        
    except Exception as exc:
        logger.warning("Failed to load credentials for user %s: %s", user_id, exc)
        return {}
```

---

## ✅ Testing Steps

After applying the fix:

1. **Create a test user (Starter tier)**
2. **Login to web app** → Go to Settings → Add OpenAI API key → Save
3. **Verify in database:**
   ```sql
   SELECT llm_api_key FROM users WHERE email = 'test@example.com';
   -- Should show encrypted JSON
   ```
4. **Test reply generation:**
   - Go to Feed
   - Select posts
   - Click "Generate Replies"
   - Should succeed (not 0 of 15)
5. **Test from mobile app:**
   - Login with same account
   - Select posts in Feed
   - Tap "Generate Replies"
   - Should succeed

---

## 📱 Mobile App Requirements (Already Implemented)

The iOS app needs to:

1. ✅ **Call `/api/api-key-status`** after user logs in
2. ✅ **Check response:**
   - `using_system_keys: true` → User is Pro/Pro+, enable all features
   - `needs_own_keys: true` + `available_providers: []` → Show "Add Keys" screen
   - `needs_own_keys: true` + `available_providers: ["openai"]` → User has keys, enable features
3. ✅ **Use existing `/api/v1/settings/llm-keys`** endpoint to save user keys
4. ✅ **Backend automatically handles key selection** - app doesn't manage keys

**Documentation:**
- API Specification: `API_IOS_SPECIFICATION.md`
- Key Management Guide: `apikeymgmt.md`

---

## 🔗 Related Code

**Middleware:** `app/middleware/user_context.py:60-109`  
**Settings API:** `app/api/v1/endpoints/settings.py:123-169`  
**LLM Service:** `app/services/llm_service.py:170-213` (consumes credentials)  
**API Key Resolver:** `app/services/api_key_resolver.py:28-72` (alternative approach)

---

## 🚨 Priority

**HIGH** - This blocks:
- All Starter tier users from using LLM features
- Mobile app reply generation
- Web app reply generation for users who saved keys via Settings page

---

## 💡 Alternative Approaches Considered

### Option 1: Use APIKeyResolver Everywhere (Recommended Long-Term)
Instead of middleware, use the `APIKeyResolver` service consistently:
- Already exists in `app/services/api_key_resolver.py`
- Already handles both Pro (system) and Starter (user) keys correctly
- Just needs to be used in `ReplyGenerator` instead of middleware credentials

### Option 2: Migrate User Keys to SystemIntegrationConfig
Move all user keys from `User.llm_api_key` to `SystemIntegrationConfig` table with name `user:{user_id}`
- Requires migration script
- Updates Settings API to save to SystemIntegrationConfig
- More complex, higher risk

### Option 3: Quick Fix (This Document)
Update middleware to also load from `User.llm_api_key`
- Minimal code change
- Low risk
- Works immediately
- **Recommended for immediate fix**

---

## 📞 Questions?

**Backend Team:** Review and implement fix in `app/middleware/user_context.py`  
**Mobile Team:** Documentation ready in `API_IOS_SPECIFICATION.md` and `apikeymgmt.md`  
**Testing:** Follow testing steps above to verify fix

---

**Issue Created:** October 31, 2025  
**Severity:** HIGH  
**Estimated Fix Time:** 30 minutes  
**Testing Time:** 15 minutes

