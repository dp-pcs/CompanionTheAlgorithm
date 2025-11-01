#!/bin/bash

# Submit backend authentication issues to main repository
# Repository: https://github.com/dp-pcs/thealgorithm

echo "🚀 Submitting backend authentication issues..."
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed."
    echo "   Install it with: brew install gh"
    echo "   Then run: gh auth login"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI."
    echo "   Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI is installed and authenticated"
echo ""

# Create the issue
echo "📝 Creating GitHub issue..."
echo ""

ISSUE_TITLE="[Mobile] Critical Authentication Issues Blocking iOS App"

ISSUE_BODY="## 🔴 Critical Issues Blocking Mobile App

Three critical authentication issues are preventing the iOS mobile app from functioning properly:

### Issue 1: Cookie Storage Python Error (\`datetime\` variable)
**Endpoint**: \`POST /api/store-cookies\`
**Error**: \`cannot access local variable 'datetime' where it is not associated with a value\`

**Impact**: 
- Mobile app successfully authenticates with X.com and extracts cookies ✅
- Cookies FAIL to be sent to backend ❌
- All endpoints requiring session cookies return 401 ❌

**Fix**: Add missing \`from datetime import datetime\` import

---

### Issue 2: \`/api/v1/replies\` Returns 401 Despite Valid OAuth Token
**Endpoint**: \`GET /api/v1/replies?status=generated\`

**Impact**:
- Reply Queue shows \"unauthorized\" despite valid token
- Other endpoints work fine with same token
- Inconsistent authentication requirements

**Fix**: Either accept OAuth token alone OR fix Issue #1 first

---

### Issue 3: TwiKit Security Error (Missing User Context)
**Endpoint**: \`POST /api/v1/replies/twikit/like-tweets-bulk\`
**Error**: \`SECURITY ERROR: TwiKit operation attempted without user context\`

**Impact**: Bulk like functionality completely broken

**Fix**: Ensure middleware sets \`current_user_id\` from OAuth token before TwiKit operations

---

## 📄 Full Details

See attached documentation: \`BACKEND_AUTH_ISSUES.md\` in mobile repo

## 🎯 Priority

**CRITICAL** - Blocks all mobile app functionality

## 🧪 Testing

After fixes:
1. Mobile app logs in via OAuth ✅
2. Mobile app stores X.com cookies → should succeed
3. \`/api/v1/replies\` with OAuth token → should return replies
4. TwiKit operations → should work without security errors"

# Create the issue
gh issue create \
    --repo dp-pcs/thealgorithm \
    --title "$ISSUE_TITLE" \
    --body "$ISSUE_BODY" \
    --label "bug,mobile,critical" 2>&1 | grep -v "label.*does not exist" || {
        echo "⚠️  Some labels may not exist, retrying without labels..."
        gh issue create \
            --repo dp-pcs/thealgorithm \
            --title "$ISSUE_TITLE" \
            --body "$ISSUE_BODY"
    }

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Issue created successfully!"
    echo ""
    echo "📎 Don't forget to attach BACKEND_AUTH_ISSUES.md to the issue for full details"
else
    echo ""
    echo "❌ Failed to create issue"
    echo ""
    echo "📝 Manual submission:"
    echo "   1. Go to: https://github.com/dp-pcs/thealgorithm/issues/new"
    echo "   2. Title: $ISSUE_TITLE"
    echo "   3. Copy content from: BACKEND_AUTH_ISSUES.md"
    echo "   4. Add labels: bug, mobile, critical"
fi

echo ""
echo "✨ Done!"

