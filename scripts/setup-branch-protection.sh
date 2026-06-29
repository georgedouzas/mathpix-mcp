#!/usr/bin/env bash
# Apply branch protection to main (strict) and dev (CI-gated).
# Requires: gh authenticated (`gh auth login`) and the repo pushed to GitHub.
#
# Usage: scripts/setup-branch-protection.sh [owner/repo]
set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
echo "Applying branch protection to ${REPO}"

# main: PR review + CODEOWNERS + passing CI + linear history, no force/deletes.
gh api -X PUT "repos/${REPO}/branches/main/protection" --input - <<'JSON'
{
  "required_status_checks": { "strict": true, "contexts": ["test (3.3)", "test (3.4)"] },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
echo "  main: protected"

# dev: require passing CI, but allow direct pushes for integration work.
gh api -X PUT "repos/${REPO}/branches/dev/protection" --input - <<'JSON'
{
  "required_status_checks": { "strict": true, "contexts": ["test (3.3)", "test (3.4)"] },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
echo "  dev: CI-gated"

echo "Done."
