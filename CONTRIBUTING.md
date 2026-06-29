# Contributing

## Branch model

- **`main`** — stable, released code. Protected: no direct pushes; changes land
  only via reviewed PRs with green CI.
- **`dev`** — integration branch for ongoing work. Feature branches and
  Dependabot PRs target `dev`.

Flow: branch off `dev` → PR into `dev` → when ready to release, PR `dev` → `main`
and tag.

## Local checks

```bash
bundle install
bundle exec rake                 # RuboCop + RSpec
bundle exec bundle-audit check   # dependency CVEs
```

## CI / CD

- **CI** (`.github/workflows/ci.yml`) runs on every push/PR to `main` and `dev`:
  RuboCop, RSpec (Ruby 3.3 & 3.4), and bundler-audit.
- **Release** (`.github/workflows/release.yml`) runs on a `v*` tag: builds the
  gem (publishes to RubyGems if `RUBYGEMS_API_KEY` is set) and builds/pushes a
  Docker image to GHCR.

### Publishing to RubyGems (one-time setup)

Publishing uses **RubyGems Trusted Publishing** (OIDC) — no API key/secret is
stored. Configure it once on rubygems.org before the first release:

1. Sign in at <https://rubygems.org>.
2. Open **Trusted Publishers → Register a new pending publisher**
   (<https://rubygems.org/profile/oidc/pending_trusted_publishers/new>) — the
   "pending" form is for gems that don't exist on RubyGems yet.
3. Fill in:
   - RubyGems gem name: `mathpix-mcp`
   - Repository owner: `georgedouzas`
   - Repository name: `mathpix-mcp`
   - Workflow filename: `release.yml`
   - Environment: *(leave blank)*
4. Save. The first `v*` tag push then publishes the gem (creating it), and
   subsequent tags publish new versions.

### Cutting a release

```bash
git checkout main && git merge --no-ff dev
# bump Mathpix::VERSION and move CHANGELOG [Unreleased] -> the new version
git commit -am "Release vX.Y.Z"
git tag vX.Y.Z && git push origin main --tags
```

The `release.yml` workflow then publishes the gem to RubyGems (trusted
publishing) and pushes a Docker image to GHCR.

## Branch protection

Applied on GitHub (a one-shot setup, already done):

- **`main`** — PR required with 1 approving review + CODEOWNERS review; CI checks
  `test (3.3)` / `test (3.4)` must pass; strict (up-to-date) + linear history;
  no force-pushes/deletions; conversation resolution required. `enforce_admins`
  is off so the sole maintainer can still merge.
- **`dev`** — CI checks required; direct pushes allowed for integration work.

To re-apply (needs `gh` authenticated):

```bash
gh api -X PUT repos/OWNER/REPO/branches/main/protection --input - <<'JSON'
{
  "required_status_checks": { "strict": true, "contexts": ["test (3.3)", "test (3.4)"] },
  "enforce_admins": false,
  "required_pull_request_reviews": { "required_approving_review_count": 1,
    "dismiss_stale_reviews": true, "require_code_owner_reviews": true },
  "restrictions": null, "required_linear_history": true,
  "allow_force_pushes": false, "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON

gh api -X PUT repos/OWNER/REPO/branches/dev/protection --input - <<'JSON'
{
  "required_status_checks": { "strict": true, "contexts": ["test (3.3)", "test (3.4)"] },
  "enforce_admins": false, "required_pull_request_reviews": null,
  "restrictions": null, "allow_force_pushes": false, "allow_deletions": false
}
JSON
```
