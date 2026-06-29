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

### Cutting a release

```bash
git checkout main && git merge --no-ff dev
# bump Mathpix::VERSION and move CHANGELOG [Unreleased] -> the new version
git commit -am "Release vX.Y.Z"
git tag vX.Y.Z && git push origin main --tags
```

## Branch protection

Branch protection is a GitHub-side setting. After the repo exists on GitHub and
`gh` is authenticated, apply it once with:

```bash
scripts/setup-branch-protection.sh            # auto-detects owner/repo
# or
scripts/setup-branch-protection.sh owner/repo
```

This requires:
- CODEOWNERS review on `main`,
- CI status checks (`test (3.3)`, `test (3.4)`) to pass,
- linear history, no force-pushes/deletions, conversation resolution.
