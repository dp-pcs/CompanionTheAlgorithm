# Reply Posting 401 Authentication Issue

## Problem

The mobile app is getting `401 Not authenticated` when trying to post replies via `POST /api/v1/replies/post/`, even though:
- ✅ The bearer token is valid (same token works for GET requests)
- ✅ X.com cookies are stored on the backend
- ✅ The request body is correct

## Evidence from Logs

```
🌐 [API] POST https://thealgorithm.live/api/v1/replies/post/
   ↳ bearer token prefix: eyJhbG… (length: 309)
   ↳ body: {"reply_id":"71c6ec43-7392-48ba-abe2-a9f03b01f95d","text":"..."}
⚠️ [API] 401 response body: {"detail":"Not authenticated"}
```

## What Works

- ✅ `GET /api/v1/replies/?status=queued` - Returns replies successfully
- ✅ `GET /api/v1/users/monitoring/status` - Works fine
- ✅ All other GET endpoints - No authentication issues

## What Fails

- ❌ `POST /api/v1/replies/post/` - Returns 401 "Not authenticated"

## User Confirmation

The user confirmed: **"definitely needs x cookies to send"**

## Expected Behavior

The endpoint should:
1. Validate the bearer token (to identify the user)
2. Retrieve the user's stored X.com cookies from the database
3. Use those cookies to post the reply to Twitter via Twikit/X API

## Hypothesis

The `/api/v1/replies/post/` endpoint might be:
1. Missing the authentication dependency that loads stored cookies
2. Using a different authentication middleware than other endpoints
3. Not configured to retrieve stored cookies from the database

## Backend Investigation Needed

Check `app/api/v1/endpoints/replies.py`:
- Is `post_reply()` using the correct authentication dependency?
- Does it have access to `current_user.twitter_cookies`?
- Is it calling the Twitter API with stored cookies?
- Compare with the web frontend's reply posting - what endpoint does it use?

## Mobile App Details

**Request Format:**
```json
POST /api/v1/replies/post/
Headers:
  Authorization: Bearer <jwt_token>
  Content-Type: application/json

Body:
{
  "reply_id": "uuid-here",
  "text": "reply text here"
}
```

**Expected Response:**
```json
{
  "success": true,
  "twitter_post_id": "123456789",
  "message": "Reply posted successfully"
}
```

## Related Endpoints That Work

For reference, these endpoints work fine with the same authentication:
- `POST /api/v1/replies/bulk-generate-and-queue` (multipart/form-data)
- `POST /api/v1/bulk-compose/sessions` (JSON)
- `POST /api/store-cookies` (JSON)

## Next Steps

1. Check backend endpoint configuration
2. Verify authentication middleware
3. Confirm cookie retrieval logic
4. Test with backend logs to see if cookies are being loaded
5. Compare with web frontend's implementation

