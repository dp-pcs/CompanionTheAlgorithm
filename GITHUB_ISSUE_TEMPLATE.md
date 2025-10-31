# 🐛 CRITICAL: Mobile App Cannot Load User LLM API Keys

**Labels:** `bug`, `high-priority`, `mobile-api`, `authentication`  
**Assignees:** Backend Team  
**Milestone:** Mobile App Integration

---

## 🎯 Summary

Users who save LLM API keys via the Settings page cannot use reply generation because the backend middleware is not loading keys from `User.llm_api_key` field. This blocks all mobile app LLM features for Starter tier users.

**Impact:** Mobile app users see "Generated 0 of 15 replies" even with valid API keys configured.

---

## 🔍 Root Cause

The backend loads credentials from two different locations, but **middleware only checks one**:

### ✅ Currently Loaded (Working)
```
SystemIntegrationConfig table
WHERE name = 'user:{user_id}'
```

### ❌ NOT Loaded (Bug!)
```
User.llm_api_key field
(Set via POST /api/v1/settings/llm-keys)
```

**Result:** Settings page saves to `User.llm_api_key`, but middleware never loads it.

---

## 📁 Affected Files

**Primary:**
- `app/middleware/user_context.py` → `_load_credentials()` (lines 60-109)

**Related:**
- `app/api/v1/endpoints/settings.py` → `save_llm_keys()` (lines 123-169)
- `app/services/llm_service.py` → `ReplyGenerator.__init__()` (lines 170-213)

---

## 🔧 The Fix

Update `app/middleware/user_context.py` → `_load_credentials()` function to also load keys from `User.llm_api_key`:

```python
async def _load_credentials(self, user_id: str) -> Dict[str, str]:
    """Load and decrypt integration credentials for the given user."""
    
    try:
        async with async_session_factory() as session:
            user = await session.get(User, user_id)
            
            # Load from SystemIntegrationConfig (existing code)
            result = await session.execute(
                select(SystemIntegrationConfig).where(
                    SystemIntegrationConfig.name == f"user:{user_id}"
                )
            )
            config = result.scalar_one_or_none()
            
            # ... existing admin fallback logic ...
        
        credentials = {}
        
        # Load from SystemIntegrationConfig (existing)
        if config:
            # ... existing credential loading code ...
        
        # 🆕 ADD THIS: Also load from User.llm_api_key
        if user and user.llm_api_key:
            try:
                from app.services.oauth_token_security import token_security
                
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

1. **Create test user (Starter tier)**
2. **Web app:** Login → Settings → Add OpenAI key → Save
3. **Verify database:**
   ```sql
   SELECT llm_api_key FROM users WHERE email = 'test@example.com';
   -- Should show encrypted JSON
   ```
4. **Test web reply generation:**
   - Go to Feed → Select posts → "Generate Replies"
   - Should succeed (not 0 of 15)
5. **Test mobile app:**
   - Login with same account
   - Feed → Select posts → "Generate Replies"
   - Should succeed

---

## 📱 Mobile App Impact

### Current State
- ❌ Mobile app cannot generate replies (0 of 15)
- ❌ Users must configure keys again (separate from web)
- ❌ Blocks iOS app launch

### After Fix
- ✅ Mobile app automatically uses web-configured keys
- ✅ Single source of truth (database)
- ✅ iOS app can launch with LLM features

---

## 📚 Documentation

Complete documentation available in mobile repo:
- **Mobile Repo:** https://github.com/dp-pcs/mobile_thealgorithm
- **Bug Details:** [BACKEND_API_KEY_BUG.md](https://github.com/dp-pcs/mobile_thealgorithm/blob/main/BACKEND_API_KEY_BUG.md)
- **API Spec:** [API_IOS_SPECIFICATION.md](https://github.com/dp-pcs/mobile_thealgorithm/blob/main/API_IOS_SPECIFICATION.md)
- **Key Management:** [apikeymgmt.md](https://github.com/dp-pcs/mobile_thealgorithm/blob/main/apikeymgmt.md)
- **Quick Reference:** [MOBILE_REQUIREMENTS_SUMMARY.md](https://github.com/dp-pcs/mobile_thealgorithm/blob/main/MOBILE_REQUIREMENTS_SUMMARY.md)

---

## 🚨 Priority Justification

**HIGH** because this blocks:
- All Starter tier users from using LLM features
- iOS mobile app launch
- Feature parity between web and mobile
- User experience (keys saved on web should work everywhere)

---

## 🔄 Alternative Approaches

### Option 1: Quick Fix (Recommended) ⭐
Update middleware to load from both locations (this issue)
- **Pros:** Minimal change, works immediately
- **Cons:** Maintains dual storage locations
- **Time:** 30 min

### Option 2: Use APIKeyResolver Service
Replace middleware approach with existing `api_key_resolver.py`
- **Pros:** Already handles both locations correctly
- **Cons:** Larger refactor across multiple services
- **Time:** 2-3 hours

### Option 3: Data Migration
Move all user keys to `SystemIntegrationConfig` table
- **Pros:** Single storage location
- **Cons:** Complex migration, higher risk
- **Time:** 4-6 hours

---

## 🧪 Acceptance Criteria

- [ ] Middleware loads keys from `User.llm_api_key` field
- [ ] User keys merged with SystemIntegrationConfig keys
- [ ] User keys take precedence over system keys (if both exist)
- [ ] Starter tier users can generate replies (not 0 of X)
- [ ] Web app continues to work
- [ ] Mobile app can generate replies
- [ ] Unit tests added for key loading logic
- [ ] Integration test for end-to-end flow

---

## 📞 Contact

**Reporter:** Mobile Team  
**Mobile Repo:** https://github.com/dp-pcs/mobile_thealgorithm  
**Backend Repo:** https://github.com/dp-pcs/thealgorithm

---

**Reported:** October 31, 2025  
**Est. Fix Time:** 30-60 minutes  
**Est. Test Time:** 15-30 minutes

