# iOS Mobile App Debugging Guide

## 🔍 How to Debug the Mobile App

Unlike web development where you have the browser console, iOS debugging uses **Xcode Console**.

---

## 📱 Step-by-Step: View Debug Logs

### 1. **Open Xcode Console**
   - Open the project in Xcode
   - Run the app on your iPhone (or Simulator)
   - **Show the console**: 
     - Menu: `View > Debug Area > Show Debug Area`
     - Or keyboard shortcut: `Cmd + Shift + Y`
     - Or click the bottom bar button with "=" icon

### 2. **Filter the Logs**
   In the console search box (bottom right), you can filter by:
   - `📤` - See API requests
   - `📄` - See API responses
   - `🔍` - See bulk operation details
   - `❌` - See errors only
   - `🔑` - See authentication
   - Or type specific keywords like "bulk generate" or "API Request"

---

## 🐛 What to Look For: "0 of 25" Issue

When you click "Generate Replies" and get "0 of 25", look for these in the console:

### **Expected Log Sequence:**

```
📤 API Request: POST https://thealgorithm.live/api/v1/replies/bulk-generate-and-queue
   Form data: ["post_ids": "1234,5678,9012..."]
   🔑 Using OAuth token: eyJhbGciOiJIUzI1Ni...

📡 Response status: 200 for /api/v1/replies/bulk-generate-and-queue
📄 Response body: {"total":25,"successful":0,"failed":25,"results":[...]}

🔍 Bulk operation results:
   Total: 25
   Successful: 0
   Failed: 25
   ❌ Post 1 (abc123): No LLM API key available
   ❌ Post 2 (def456): No LLM API key available
   ❌ Post 3 (ghi789): No LLM API key available
   ...
```

### **Key Things to Check:**

1. **Is the token present?**
   ```
   🔑 Using OAuth token: eyJhbGci...
   ```
   - ✅ If you see this → Auth is working
   - ❌ If you see `⚠️ No OAuth token available!` → Re-login

2. **What's the response status?**
   ```
   📡 Response status: 200
   ```
   - ✅ `200` → Request succeeded (but results may still fail)
   - ❌ `401` → Auth issue
   - ❌ `500` → Backend error

3. **What do the error messages say?**
   ```
   ❌ Post 1 (abc123): No LLM API key available
   ```
   - This confirms the backend bug we reported in **Issue #21**
   - Backend isn't loading your stored LLM keys from `User.llm_api_key`

---

## 🔧 Additional Debug Commands

### Check if LLM Keys Exist on Backend

Add this test to verify your keys are stored:

```swift
// In APIClient.swift, add this temporary debug function:
func debugCheckKeys(completion: @escaping (Result<String, Error>) -> Void) {
    performRequest(path: "/api/v1/settings/status", method: "GET", completion: completion)
}
```

Then call it from your view:
```swift
apiClient.debugCheckKeys { result in
    switch result {
    case .success(let response):
        print("🔐 Settings status: \(response)")
    case .failure(let error):
        print("❌ Failed to check settings: \(error)")
    }
}
```

### Enable Network Traffic Inspection

For even more detailed debugging, you can use **Charles Proxy** or **Proxyman**:

1. Install [Proxyman](https://proxyman.io/) (free for basic use)
2. Configure your iPhone to use the proxy
3. See ALL HTTP requests/responses in detail
4. View request headers, body, response body

---

## 📊 Common Patterns

### Pattern 1: All Fail with "No LLM API key"
**Cause:** Backend bug (Issue #21) - middleware not loading user keys  
**Solution:** Wait for backend team to apply the fix

### Pattern 2: Some Succeed, Some Fail
**Cause:** Rate limits or API errors from LLM providers  
**Action:** Check individual error messages in console

### Pattern 3: HTTP 401 Unauthorized
**Cause:** OAuth token expired or invalid  
**Solution:** Log out and log back in

### Pattern 4: HTTP 500 Server Error
**Cause:** Backend crash or unhandled error  
**Action:** Share full error response with backend team

---

## 💡 Pro Tips

### 1. **Clear Logs Between Tests**
   - Click the trash can icon in console (🗑️)
   - Or `Cmd + K`

### 2. **Copy Console Output**
   - Right-click in console → `Select All`
   - `Cmd + C` to copy
   - Paste into bug reports

### 3. **Filter by Subsystem**
   - Click the filter dropdown
   - Select your app bundle ID
   - Removes system noise

### 4. **Breakpoints for Step-Through**
   - Click line number in Xcode → adds blue breakpoint
   - App pauses there
   - Inspect variables in debug area

---

## 🎯 Your Specific Issue

Based on the "0 of 25" result, you'll likely see:

```
🔍 Bulk operation results:
   Total: 25
   Successful: 0
   Failed: 25
   ❌ Post 1 (xxx): No LLM API key available
   ❌ Post 2 (xxx): No LLM API key available
   [... all 25 with same error ...]
```

**This confirms:**
- ✅ Mobile app is working correctly
- ✅ API call is being made successfully
- ✅ Backend receives the request
- ❌ Backend doesn't load your stored LLM keys (Issue #21)

Once the backend team merges the fix from Issue #21, you should see:
```
🔍 Bulk operation results:
   Total: 25
   Successful: 25  ← Success!
   Failed: 0
```

---

## 📞 Need More Help?

If you're still stuck after checking the console:

1. **Copy the full console output** from when you click "Generate Replies"
2. **Take a screenshot** of the console
3. **Share** with the backend team or in GitHub issue

The detailed logging we just added will show exactly what's happening! 🚀

