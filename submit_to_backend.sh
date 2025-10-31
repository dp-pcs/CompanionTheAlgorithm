#!/bin/bash
# Submit mobile app bug and documentation to backend repository
# Run this script to create a GitHub issue automatically

set -e

BACKEND_REPO="dp-pcs/thealgorithm"
ISSUE_TITLE="🐛 CRITICAL: Mobile App Cannot Load User LLM API Keys"
ISSUE_FILE="GITHUB_ISSUE_TEMPLATE.md"

echo "🚀 Submitting issue to backend repository..."
echo "Repository: https://github.com/$BACKEND_REPO"
echo ""

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed!"
    echo ""
    echo "Install it with:"
    echo "  brew install gh"
    echo ""
    echo "Then authenticate:"
    echo "  gh auth login"
    echo ""
    echo "After installation, run this script again."
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI!"
    echo ""
    echo "Authenticate with:"
    echo "  gh auth login"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "✅ GitHub CLI authenticated"
echo ""

# Create the issue
echo "📝 Creating GitHub issue..."

# Try with labels, but continue even if labels don't exist
ISSUE_URL=$(gh issue create \
    --repo "$BACKEND_REPO" \
    --title "$ISSUE_TITLE" \
    --body-file "$ISSUE_FILE" \
    --assignee "@me" 2>&1 || true)

# Try to add labels separately (fails gracefully if labels don't exist)
if [[ $ISSUE_URL =~ github.com/.*/([0-9]+) ]]; then
    ISSUE_NUMBER="${BASH_REMATCH[1]}"
    echo "   Attempting to add labels..."
    gh issue edit "$ISSUE_NUMBER" --repo "$BACKEND_REPO" --add-label "bug" 2>/dev/null || echo "   ⚠️  'bug' label not found (skipping)"
    gh issue edit "$ISSUE_NUMBER" --repo "$BACKEND_REPO" --add-label "mobile" 2>/dev/null || echo "   ⚠️  'mobile' label not found (skipping)"
    gh issue edit "$ISSUE_NUMBER" --repo "$BACKEND_REPO" --add-label "priority:high" 2>/dev/null || echo "   ⚠️  'priority:high' label not found (skipping)"
fi

echo ""
echo "✅ Issue created successfully!"
echo ""
echo "🔗 Issue URL: $ISSUE_URL"
echo ""
echo "📋 Next steps:"
echo "1. Visit the issue to add any additional context"
echo "2. Assign to specific backend team members if needed"
echo "3. Link to related issues or PRs"
echo ""
echo "📚 All documentation is available in the mobile repo:"
echo "   https://github.com/dp-pcs/mobile_thealgorithm"
echo ""
echo "   - BACKEND_API_KEY_BUG.md (detailed fix)"
echo "   - API_IOS_SPECIFICATION.md (API spec)"
echo "   - apikeymgmt.md (key management guide)"
echo "   - MOBILE_REQUIREMENTS_SUMMARY.md (quick reference)"
echo ""

