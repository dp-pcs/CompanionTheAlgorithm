#!/bin/bash

# Submit reply posting authentication issue to main repository

ISSUE_FILE="REPLY_POST_AUTH_ISSUE.md"
REPO_OWNER="dp-pcs"
REPO_NAME="thealgorithm"

if [ ! -f "$ISSUE_FILE" ]; then
    echo "❌ Error: $ISSUE_FILE not found"
    exit 1
fi

echo "📋 Submitting reply posting auth issue to $REPO_OWNER/$REPO_NAME..."

# Read the markdown file
ISSUE_BODY=$(cat "$ISSUE_FILE")

# Create the issue
gh issue create \
    --repo "$REPO_OWNER/$REPO_NAME" \
    --title "🐛 Mobile: POST /api/v1/replies/post/ returns 401 even with valid bearer token" \
    --body "$ISSUE_BODY"

if [ $? -eq 0 ]; then
    echo "✅ Issue submitted successfully!"
    echo ""
    echo "View the issue at: https://github.com/$REPO_OWNER/$REPO_NAME/issues"
else
    echo "❌ Failed to create issue"
    exit 1
fi

