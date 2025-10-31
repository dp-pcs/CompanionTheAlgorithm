# 🔑 API Key Management for iOS App

**Understanding LLM API Key Storage and Usage**

---

## 📋 Overview

The Algorithm uses different API key strategies based on user subscription tier:

- **Pro / Pro+ Users** → Use system-provided keys (backend provides them)
- **Starter Users** → Must provide their own keys (BYOK - Bring Your Own Key)

---

## 🗄️ Where Are Keys Stored?

### System Keys (Pro/Pro+)

**Location:** Backend environment variables

```bash
# In backend .env file
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_API_KEY=AIza...
```

**Access:** These are loaded from environment variables and stored in memory on the backend server.

**Code:** `app/core/config.py` → `Settings` class

### User Keys (Starter)

**Location:** Database table `users`, column `llm_api_key`

**Storage Format:**
- Encrypted JSON string
- Contains: `{"openai": "sk-...", "anthropic": "sk-ant-...", "google": "AIza..."}`
- Encrypted using `app/services/oauth_token_security.py`

**Code:** `app/models/user.py` → `User.llm_api_key` field

---

## 🔐 How Key Resolution Works

### The APIKeyResolver Service

**Location:** `app/services/api_key_resolver.py`

**Logic:**
```python
class APIKeyResolver:
    PRO_TIERS = {'pro', 'pro_plus', 'pro_trial'}
    
    def get_api_key(user, provider):
        # Pro/Pro+ users get system keys
        if user.plan_tier in PRO_TIERS:
            return SYSTEM_KEYS[provider]  # From environment
        
        # Starter users use their own keys
        if user.llm_api_key:
            user_keys = decrypt(user.llm_api_key)
            return user_keys[provider]
        
        return None  # No key available
```

**When backend needs an LLM key:**
1. Check user's `plan_tier`
2. If Pro/Pro+ → Use system environment keys
3. If Starter → Decrypt user's `llm_api_key` from database
4. Return the appropriate key

---

## 📱 How iOS App Should Handle This

### Step 1: Check User's Key Status

**New Endpoint:** `GET /api/api-key-status`

Call this after user logs in:

```swift
func checkAPIKeyStatus() async throws {
    let url = URL(string: "https://thealgorithm.live/api/api-key-status")!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    
    let (data, _) = try await URLSession.shared.data(for: request)
    let status = try JSONDecoder().decode(APIKeyStatusResponse.self, from: data)
    
    return status
}
```

**Response:**
```json
{
  "key_source": "system" | "user",
  "plan_tier": "pro" | "pro_plus" | "starter" | "free",
  "using_system_keys": true | false,
  "needs_own_keys": true | false,
  "available_providers": ["openai", "anthropic"],
  "provider_details": {
    "openai": {"available": true, "source": "system"},
    "anthropic": {"available": true, "source": "system"},
    "google": {"available": false, "source": null}
  }
}
```

### Step 2: Handle Different Scenarios

#### Scenario A: Pro/Pro+ User (System Keys)

```swift
if status.using_system_keys {
    // User can use LLM features immediately
    // Backend will use system keys automatically
    // No action needed from iOS app
    enableAllLLMFeatures()
}
```

**What happens:**
- iOS app makes requests normally
- Backend automatically uses system keys
- User doesn't need to configure anything

#### Scenario B: Starter User with Keys

```swift
if status.needs_own_keys && !status.available_providers.isEmpty {
    // User has configured their keys
    // They can use LLM features
    enableLLMFeatures(providers: status.available_providers)
}
```

**What happens:**
- User previously configured their keys via web app or iOS app
- Keys are stored encrypted in database
- Backend retrieves and uses user's keys

#### Scenario C: Starter User without Keys

```swift
if status.needs_own_keys && status.available_providers.isEmpty {
    // User needs to add their own API keys
    showAPIKeySetupScreen()
}
```

**What happens:**
- Show UI prompting user to add API keys
- User enters keys in iOS app
- iOS app sends keys to backend
- Backend encrypts and stores keys

### Step 3: Let User Add Keys (Starter Only)

**Endpoint:** `POST /api/v1/settings/llm-keys` (existing)

```swift
struct LLMKeysRequest: Codable {
    let openai: String?
    let anthropic: String?
    let google: String?
}

func saveLLMKeys(openai: String?, anthropic: String?, google: String?) async throws {
    let url = URL(string: "https://thealgorithm.live/api/v1/settings/llm-keys")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body = LLMKeysRequest(
        openai: openai,
        anthropic: anthropic,
        google: google
    )
    request.httpBody = try JSONEncoder().encode(body)
    
    let (_, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw APIError.failedToSaveKeys
    }
}
```

---

## 🎯 iOS App Flow Diagram

```
App Launch
    ↓
User Logs In (OAuth)
    ↓
GET /api/api-key-status
    ↓
┌───────────────────────────────────┐
│ Check response                     │
└───────────────────────────────────┘
         ↓
    ┌────┴─────┐
    │          │
Pro/Pro+    Starter
(system)     (user)
    │          │
    ↓          ↓
Enable      Has keys?
All         ├─ Yes → Enable LLM
Features    └─ No  → Show "Add Keys" screen
                         ↓
                    User enters keys
                         ↓
                    POST /api/v1/settings/llm-keys
                         ↓
                    Keys saved & encrypted
                         ↓
                    Enable LLM features
```

---

## 🔄 Complete Implementation Example

```swift
// APIKeyStatusResponse.swift
struct APIKeyStatusResponse: Codable {
    let keySource: String
    let planTier: String
    let usingSystemKeys: Bool
    let needsOwnKeys: Bool
    let availableProviders: [String]
    let providerDetails: [String: ProviderDetail]
    
    enum CodingKeys: String, CodingKey {
        case keySource = "key_source"
        case planTier = "plan_tier"
        case usingSystemKeys = "using_system_keys"
        case needsOwnKeys = "needs_own_keys"
        case availableProviders = "available_providers"
        case providerDetails = "provider_details"
    }
}

struct ProviderDetail: Codable {
    let available: Bool
    let source: String?
}

// APIKeyManager.swift
class APIKeyManager {
    
    func checkStatus(accessToken: String) async throws -> APIKeyStatusResponse {
        let url = URL(string: "https://thealgorithm.live/api/api-key-status")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(APIKeyStatusResponse.self, from: data)
    }
    
    func handleKeyStatus(_ status: APIKeyStatusResponse) {
        if status.usingSystemKeys {
            // Pro/Pro+ user - all set!
            print("User has system keys - ready to use LLM features")
            NotificationCenter.default.post(name: .llmFeaturesReady, object: nil)
        } else if status.needsOwnKeys {
            if status.availableProviders.isEmpty {
                // Starter user without keys
                print("User needs to add API keys")
                NotificationCenter.default.post(name: .needsAPIKeys, object: nil)
            } else {
                // Starter user with keys
                print("User has own keys - ready to use: \(status.availableProviders)")
                NotificationCenter.default.post(
                    name: .llmFeaturesReady,
                    object: status.availableProviders
                )
            }
        }
    }
    
    func saveKeys(openai: String?, anthropic: String?, google: String?, accessToken: String) async throws {
        let url = URL(string: "https://thealgorithm.live/api/v1/settings/llm-keys")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String?] = [
            "openai": openai,
            "anthropic": anthropic,
            "google": google
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.failedToSaveKeys
        }
    }
}

// Usage in ViewController
class MainViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLLMFeaturesReady),
            name: .llmFeaturesReady,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNeedsAPIKeys),
            name: .needsAPIKeys,
            object: nil
        )
    }
    
    func checkAPIKeys() {
        Task {
            do {
                let status = try await APIKeyManager().checkStatus(accessToken: accessToken)
                APIKeyManager().handleKeyStatus(status)
            } catch {
                print("Failed to check API key status: \(error)")
            }
        }
    }
    
    @objc func handleLLMFeaturesReady() {
        // Enable LLM-based features in UI
        enableReplyGeneration()
        enableContentSuggestions()
    }
    
    @objc func handleNeedsAPIKeys() {
        // Show API key setup screen
        let setupVC = APIKeySetupViewController()
        present(setupVC, animated: true)
    }
}

// NotificationCenter extensions
extension Notification.Name {
    static let llmFeaturesReady = Notification.Name("llmFeaturesReady")
    static let needsAPIKeys = Notification.Name("needsAPIKeys")
}
```

---

## 📝 Summary for iOS Team

**The mobile app should:**

1. **After login, call** `GET /api/api-key-status`
2. **Check the response:**
   - `using_system_keys: true` → User is Pro/Pro+, all set!
   - `needs_own_keys: true` + `available_providers: []` → Show "Add Keys" screen
   - `needs_own_keys: true` + `available_providers: ["openai"]` → User has keys, all set!
3. **If user needs to add keys:**
   - Show UI to input API keys
   - Call `POST /api/v1/settings/llm-keys`
   - Re-check status
4. **Backend handles everything else:**
   - Pro/Pro+ → Backend uses system keys automatically
   - Starter → Backend retrieves user's encrypted keys automatically

**The mobile app does NOT:**
- Store LLM API keys locally (security risk)
- Need to pass keys in API requests
- Need to know which key to use

**The backend handles:**
- Key storage (encrypted)
- Key selection based on tier
- Using the right key for each request

---

## 🔗 API Endpoints Reference

| Endpoint | Method | Purpose | Auth Required |
|----------|--------|---------|---------------|
| `/api/api-key-status` | GET | Check user's key configuration | Yes (Bearer) |
| `/api/v1/settings/llm-keys` | GET | Get user's saved keys (masked) | Yes (Session or Bearer) |
| `/api/v1/settings/llm-keys` | POST | Save/update user's keys | Yes (Session or Bearer) |

---

## 🚨 Important Security Notes

**DO:**
- ✅ Call `/api/api-key-status` on app launch
- ✅ Send keys over HTTPS only
- ✅ Clear key input fields after submission
- ✅ Show masked keys in settings (e.g., "sk-...xyz123")

**DON'T:**
- ❌ Store keys in iOS app locally
- ❌ Log keys to console
- ❌ Include keys in analytics
- ❌ Send keys to third-party services

---

**Last Updated:** October 31, 2025  
**Backend API:** `/api/api-key-status` (NEW)  
**Subscription Tiers:** Pro/Pro+ (system) | Starter (BYOK)

