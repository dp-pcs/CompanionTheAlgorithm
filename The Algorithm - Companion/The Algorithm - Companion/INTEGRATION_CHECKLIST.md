# 🔗 Integration Checklist - Connect iOS App to thealgorithm.live

This checklist walks you through connecting your iOS app to the thealgorithm.live backend.

## ✅ Prerequisites

- [ ] thealgorithm.live backend is deployed and accessible via HTTPS
- [ ] Backend has OAuth provider implementation (see `backend_integration.md`)
- [ ] Database migrations have been run (`alembic upgrade head`)
- [ ] Xcode installed on macOS

## 📋 Step-by-Step Integration

### Step 1: Register iOS App as OAuth Client

**On your backend server:**

```bash
# Run the registration script
python scripts/register_ios_oauth_client.py
```

**Expected output:**
```
✅ OAuth Client Registered Successfully!

Client ID:        ios_app_abc123def456789
Client Type:      public (mobile app)
Redirect URI:     thealgorithm://oauth/callback
Allowed Scopes:   read, write
Is Trusted:       Yes
PKCE Required:    Yes

📋 Next Steps:
1. Copy the Client ID above
2. Update AuthenticationManager.swift line 12
3. Build and test the iOS app
```

**Important:** Copy the `Client ID` - you'll need it in the next step!

---

### Step 2: Configure iOS App with Client ID

**On your Mac:**

1. Open the iOS project:
   ```bash
   cd /Users/davidproctor/Documents/GitHub/App_TheAlgorithm
   open TwitterCookieApp/TwitterCookieApp.xcodeproj
   ```

2. In Xcode, open `TwitterCookieApp/AuthenticationManager.swift`

3. Find line 12 and update it:
   ```swift
   // BEFORE:
   private let clientID = "your_client_id"
   
   // AFTER (use YOUR actual client ID from Step 1):
   private let clientID = "ios_app_abc123def456789"
   ```

4. Save the file (⌘ + S)

---

### Step 3: Verify Backend Configuration

**Check these endpoints are accessible:**

```bash
# Health check (should return 200 OK)
curl https://thealgorithm.live/api/health

# OAuth authorize endpoint (should return HTML login page or redirect)
curl -I https://thealgorithm.live/oauth/authorize

# OAuth token endpoint (should return 400 or 401, not 404)
curl -X POST https://thealgorithm.live/oauth/token
```

**Expected results:**
- `/api/health` → `{"status":"healthy","version":"1.0.0"}`
- `/oauth/authorize` → 200 OK or 302 Redirect
- `/oauth/token` → 400 Bad Request (missing parameters)

If any endpoint returns 404, your backend routes are not configured correctly.

---

### Step 4: Test OAuth Flow

**In Xcode:**

1. Select iPhone simulator (or connected device)
2. Press **⌘ + R** to build and run
3. Wait for app to launch

**In the iOS app:**

1. Tap **"Authenticate with Your Service"**
   - Should open Safari or in-app browser
   - Should navigate to `https://thealgorithm.live/oauth/authorize`
   
2. **Log in to thealgorithm.live**
   - Use your X (Twitter) OAuth credentials
   - Grant access to the iOS app
   
3. **Should redirect back to iOS app**
   - URL: `thealgorithm://oauth/callback?code=...`
   - App automatically exchanges code for token
   
4. **Check status label**
   - Should show: "✅ Ready to authenticate with X.com"

**If this works:** OAuth integration is complete! ✅

**If it fails:** See troubleshooting section below

---

### Step 5: Test X.com Cookie Extraction

**In the iOS app:**

1. Tap **"Authenticate with X.com"**
   - WebView should open showing x.com/login
   
2. **Log in to X.com**
   - Enter your X credentials
   - Complete any 2FA if required
   - Wait for home timeline to load
   
3. **Cookies extracted automatically**
   - WebView should close
   - Status should show: "✅ Ready to send messages"
   - Cookies sent to backend via `/api/store-cookies`

**Verify on backend:**

```bash
# Check if cookies were stored
psql your_database -c "SELECT user_id, created_via, created_at FROM x_sessions WHERE created_via = 'ios_app' ORDER BY created_at DESC LIMIT 5;"
```

**If this works:** Cookie extraction is complete! ✅

---

### Step 6: Test Message Sending

**In the iOS app:**

1. Type a test message in the text field
   - Example: "Testing iOS app integration! 🚀"
   
2. Tap **"Send Message"**
   - Should show progress indicator
   - Should call `/api/send-message` endpoint
   
3. **Check for success message**
   - Should show: "Message sent successfully!"

**Verify on backend:**

Check your backend logs to see the message was received and processed.

**If this works:** Full integration is complete! 🎉

---

## 🔍 Verification Checklist

After completing all steps, verify:

- [ ] OAuth client is registered in database
- [ ] iOS app has correct client ID
- [ ] iOS app successfully authenticates with thealgorithm.live
- [ ] Access token is stored in iOS Keychain
- [ ] X.com WebView loads correctly
- [ ] X.com cookies are extracted
- [ ] Cookies are sent to backend
- [ ] Cookies are stored in database
- [ ] Messages can be sent via API
- [ ] Backend can use stored cookies

## 🐛 Troubleshooting

### Issue: "Invalid client_id"

**Cause:** Client not registered or inactive

**Solution:**
```bash
# Check database
psql your_database -c "SELECT id, name, is_active FROM oauth_clients WHERE name = 'iOS App';"

# If not found or inactive, run registration again
python scripts/register_ios_oauth_client.py
```

---

### Issue: "Invalid redirect_uri"

**Cause:** Redirect URI mismatch

**iOS app uses:** `thealgorithm://oauth/callback`

**Check backend:**
```bash
psql your_database -c "SELECT redirect_uris FROM oauth_clients WHERE name = 'iOS App';"
```

**Should show:** `["thealgorithm://oauth/callback"]`

**If different:** Update in database or re-register client

---

### Issue: "PKCE verification failed"

**Cause:** iOS app's PKCE implementation issue

**Solution:**
1. Make sure you updated AuthenticationManager.swift with PKCE support (should be done already)
2. Check Xcode console for PKCE-related errors
3. Verify `code_challenge` is being sent in authorize request
4. Verify `code_verifier` is being sent in token request

**Debug in Xcode console:**
Look for these log messages:
```
✅ Generated PKCE codes successfully
🌐 Authorize URL: https://thealgorithm.live/oauth/authorize?...code_challenge=...
🔄 Exchanging code for token with verifier
```

---

### Issue: "Authorization code expired"

**Cause:** Took too long between authorize and token exchange

**Backend:** Codes expire in 10 minutes

**Solution:** Start OAuth flow again

---

### Issue: "Access token invalid or expired"

**Cause:** Token expired (24 hour lifetime)

**Solution:** Re-authenticate (OAuth flow again)

**Future enhancement:** Implement refresh tokens

---

### Issue: WebView shows blank page

**Cause:** Network issue or incorrect URL

**Solution:**
1. Check internet connection
2. Verify `https://thealgorithm.live` is accessible
3. Check Xcode console for network errors
4. Try opening URL in Safari: `https://thealgorithm.live/oauth/authorize`

---

### Issue: Cookies not extracted

**Cause:** User didn't complete X.com login

**Solution:**
1. Make sure user reaches X.com home timeline
2. WebView must show `x.com/home` or `x.com/timeline`
3. Check Xcode console for cookie count
4. Look for: `✅ Stored X cookies securely`

---

### Issue: Backend returns 404 for API calls

**Cause:** Routes not registered or CORS issue

**Solution:**
1. Check backend is running
2. Verify routes are registered in FastAPI/Flask
3. Check CORS settings allow iOS app
4. Test endpoints with curl first

---

## 📊 Backend Integration Status

Based on your `backend_integration.md`, here's what should be implemented:

### ✅ Already Implemented (Backend)
- OAuth provider tables (oauth_clients, oauth_authorization_codes, oauth_access_tokens)
- OAuth endpoints (/oauth/authorize, /oauth/token, /oauth/revoke)
- PKCE support (required for mobile apps)
- JWT token generation and validation
- API endpoints (/api/store-cookies, /api/send-message, /api/health)
- Admin endpoints for managing OAuth clients
- Token revocation support

### ✅ Already Implemented (iOS App)
- OAuth 2.0 authorization code flow
- PKCE support (code_challenge, code_verifier)
- Token storage in iOS Keychain
- X.com WebView authentication
- Cookie extraction from WebView
- API client with Bearer token authentication
- Error handling and user feedback

### 🔧 What You Need to Do
1. Run `python scripts/register_ios_oauth_client.py` (once)
2. Update iOS app with client ID (one line change)
3. Build and test the app

## 🎯 Success Criteria

You've successfully integrated when:

1. ✅ iOS app opens Safari/WebView for OAuth
2. ✅ User logs in to thealgorithm.live with X OAuth
3. ✅ App receives authorization code
4. ✅ App exchanges code for access token
5. ✅ Token is stored in iOS Keychain
6. ✅ X.com WebView login works
7. ✅ Cookies are extracted and stored
8. ✅ Backend receives cookies via API
9. ✅ Messages can be sent using stored cookies
10. ✅ User can use app without re-authenticating

## 📱 Testing Recommendations

### Test on Simulator First
- Fastest iteration
- Easy debugging with Xcode console
- Can test OAuth flow completely

### Then Test on Real Device
- More realistic user experience
- Better performance
- Required for App Store submission

### Use TestFlight for Beta Testing
- Share with friends/team
- Get feedback before App Store
- Track crashes and issues

## 🔐 Security Verification

Verify these security features are working:

- [ ] PKCE is being used (check authorize URL)
- [ ] State parameter prevents CSRF
- [ ] Authorization codes are single-use
- [ ] Authorization codes expire (10 minutes)
- [ ] Access tokens expire (24 hours)
- [ ] Tokens stored securely in Keychain
- [ ] HTTPS enforced for all API calls
- [ ] Cookies stored securely in backend database
- [ ] Backend validates tokens on all API calls

## 📞 Need Help?

If you're stuck:

1. **Check Xcode Console** - Look for error messages
2. **Check Backend Logs** - See what requests are arriving
3. **Test Endpoints Manually** - Use curl or Postman
4. **Read backend_integration.md** - Detailed backend documentation
5. **Check Database** - Verify OAuth client is registered

## 🎉 Next Steps After Integration

Once everything works:

1. **Add App Icon** - Make it look professional
2. **Customize UI** - Match your branding
3. **Add More Features** - Build on this foundation
4. **TestFlight Beta** - Get user feedback
5. **App Store Submission** - Go live!

---

**Ready to integrate?** Start with Step 1 above! 🚀

