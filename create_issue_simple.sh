#!/bin/bash
# Simple GitHub issue creation without labels
# This version works even if repository has no labels configured

set -e

BACKEND_REPO="dp-pcs/thealgorithm"
ISSUE_TITLE="🐛 CRITICAL: Mobile App Cannot Load User LLM API Keys"
ISSUE_FILE="GITHUB_ISSUE_TEMPLATE.md"

echo "🚀 Creating GitHub issue..."
echo "Repository: https://github.com/$BACKEND_REPO"
echo ""

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed!"
    echo ""
    echo "Install with: brew install gh"
    echo "Then authenticate: gh auth login"
    exit 1
fi

# Check authentication
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI authenticated"
echo ""

# Create issue without labels or assignee (most reliable)
echo "📝 Creating issue..."
ISSUE_URL=$(gh issue create \
    --repo "$BACKEND_REPO" \
    --title "$ISSUE_TITLE" \
    --body-file "$ISSUE_FILE")

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS! Issue created:"
    echo ""
    echo "🔗 $ISSUE_URL"
    echo ""
    echo "📋 Next steps:"
    echo "1. Visit the issue URL above"
    echo "2. Add labels if available: bug, mobile, priority"
    echo "3. Assign to backend team members"
    echo "4. Backend team has all info needed to fix!"
    echo ""
else
    echo ""
    echo "❌ Failed to create issue"
    echo ""
    echo "Manual method:"
    echo "1. Go to: https://github.com/$BACKEND_REPO/issues/new"
    echo "2. Copy contents from: GITHUB_ISSUE_TEMPLATE.md"
    echo "3. Title: $ISSUE_TITLE"
    echo ""
fi

