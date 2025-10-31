# How to Submit Bug to Backend Repository

You have **two options** to submit this issue to the backend team:

---

## Option 1: Automated (Recommended) 🚀

### Prerequisites
1. Install GitHub CLI:
   ```bash
   brew install gh
   ```

2. Authenticate:
   ```bash
   gh auth login
   ```

### Submit the Issue
```bash
./submit_to_backend.sh
```

This will automatically:
- Create a GitHub issue on `dp-pcs/thealgorithm`
- Include all bug details and fix instructions
- Add appropriate labels (`bug`, `high-priority`, `mobile-api`)
- Give you a direct link to the issue

---

## Option 2: Manual 📝

### Step 1: Go to Backend Repository
Visit: https://github.com/dp-pcs/thealgorithm/issues/new

### Step 2: Copy Issue Content
Open `GITHUB_ISSUE_TEMPLATE.md` and copy the entire contents

### Step 3: Create Issue
- **Title:** `🐛 CRITICAL: Mobile App Cannot Load User LLM API Keys`
- **Body:** Paste the content from `GITHUB_ISSUE_TEMPLATE.md`
- **Labels:** `bug`, `high-priority`, `mobile-api`
- **Assignees:** Your backend team members

### Step 4: Reference Documentation
In the issue, link to the mobile repo documentation:
```markdown
📚 Complete documentation:
- [BACKEND_API_KEY_BUG.md](https://github.com/dp-pcs/mobile_thealgorithm/blob/main/BACKEND_API_KEY_BUG.md)
- [API_IOS_SPECIFICATION.md](https://github.com/dp-pcs/mobile_thealgorithm/blob/main/API_IOS_SPECIFICATION.md)
- [apikeymgmt.md](https://github.com/dp-pcs/mobile_thealgorithm/blob/main/apikeymgmt.md)
```

---

## Option 3: Create PR with Docs (Optional)

If you want to add the mobile documentation to the backend repository:

### Step 1: Clone Backend Repo
```bash
cd ~/Documents/GitHub
git clone https://github.com/dp-pcs/thealgorithm.git
cd thealgorithm
```

### Step 2: Create Branch
```bash
git checkout -b feature/mobile-app-docs
```

### Step 3: Copy Documentation
```bash
mkdir -p docs/mobile
cp ~/Documents/GitHub/mobile_thealgorithm/BACKEND_API_KEY_BUG.md docs/mobile/
cp ~/Documents/GitHub/mobile_thealgorithm/API_IOS_SPECIFICATION.md docs/mobile/
cp ~/Documents/GitHub/mobile_thealgorithm/apikeymgmt.md docs/mobile/
cp ~/Documents/GitHub/mobile_thealgorithm/MOBILE_REQUIREMENTS_SUMMARY.md docs/mobile/
```

### Step 4: Commit and Push
```bash
git add docs/mobile/
git commit -m "Add mobile app integration documentation

- API specification for iOS team
- LLM API key management guide
- Backend bug report with fix
- Quick reference for backend team

Fixes #XXX (issue number from step above)"

git push origin feature/mobile-app-docs
```

### Step 5: Create PR
```bash
gh pr create \
  --title "Add mobile app integration documentation" \
  --body "Documentation for mobile app integration. See docs/mobile/ directory. Related to issue #XXX" \
  --label "documentation,mobile-api"
```

Or visit: https://github.com/dp-pcs/thealgorithm/compare

---

## Quick Command Reference

### Using GitHub CLI

**Create Issue:**
```bash
gh issue create \
  --repo dp-pcs/thealgorithm \
  --title "🐛 CRITICAL: Mobile App Cannot Load User LLM API Keys" \
  --body-file GITHUB_ISSUE_TEMPLATE.md \
  --label "bug,high-priority,mobile-api"
```

**View Your Issues:**
```bash
gh issue list --repo dp-pcs/thealgorithm --author "@me"
```

**View Issue:**
```bash
gh issue view <issue-number> --repo dp-pcs/thealgorithm
```

**Add Comment:**
```bash
gh issue comment <issue-number> --repo dp-pcs/thealgorithm --body "Additional context..."
```

---

## What Happens Next?

1. **Backend team receives notification** of new high-priority issue
2. **They review** the bug details and fix in `BACKEND_API_KEY_BUG.md`
3. **They apply the fix** to `app/middleware/user_context.py`
4. **They test** using the testing steps provided
5. **They close the issue** and notify mobile team
6. **Mobile app works!** 🎉

---

## Files Ready to Submit

All files are committed and available at:
https://github.com/dp-pcs/mobile_thealgorithm

- ✅ `GITHUB_ISSUE_TEMPLATE.md` - Ready to submit
- ✅ `BACKEND_API_KEY_BUG.md` - Complete fix with code
- ✅ `API_IOS_SPECIFICATION.md` - API documentation
- ✅ `apikeymgmt.md` - Key management guide
- ✅ `MOBILE_REQUIREMENTS_SUMMARY.md` - Quick reference

---

## Need Help?

**If automated submission fails:**
- Check GitHub CLI authentication: `gh auth status`
- Check repository access: `gh repo view dp-pcs/thealgorithm`
- Use manual method (Option 2) instead

**If you need to update the issue:**
- Use `gh issue edit <number>` to modify
- Or comment with additional info: `gh issue comment <number>`

**If backend team has questions:**
- Point them to mobile repo: https://github.com/dp-pcs/mobile_thealgorithm
- All documentation includes code examples and testing steps
- Mobile team is ready to assist with integration testing

---

**Repository URLs:**
- **Backend:** https://github.com/dp-pcs/thealgorithm
- **Mobile:** https://github.com/dp-pcs/mobile_thealgorithm

**Issue Template:** `GITHUB_ISSUE_TEMPLATE.md`  
**Submission Script:** `./submit_to_backend.sh`

