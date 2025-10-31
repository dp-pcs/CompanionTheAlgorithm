#!/bin/bash

# Submit GitHub Issue for API Documentation Update
# This script creates an issue in the main backend repository

REPO="dp-pcs/thealgorithm"
TITLE="Update API Documentation: bulk-generate-and-queue response includes reply_id field"

echo "📝 Submitting issue to $REPO..."
echo ""
echo "Title: $TITLE"
echo ""

# Create the issue using the markdown file
gh issue create \
  --repo "$REPO" \
  --title "$TITLE" \
  --body-file "ISSUE_API_DOCS_UPDATE.md"

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Issue created successfully!"
  echo ""
  echo "📋 The backend team can now see:"
  echo "   - Actual vs documented response format"
  echo "   - The missing reply_id field"
  echo "   - Impact on mobile app"
  echo "   - Recommended documentation updates"
  echo ""
else
  echo ""
  echo "❌ Failed to create issue"
  echo ""
  echo "You can create the issue manually at:"
  echo "  https://github.com/$REPO/issues/new"
  echo ""
  echo "Copy the contents from: ISSUE_API_DOCS_UPDATE.md"
  exit 1
fi
