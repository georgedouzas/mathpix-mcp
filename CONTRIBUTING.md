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

## Releasing & repository administration

Cutting releases, RubyGems trusted-publishing setup, and branch-protection
configuration are maintainer tasks — see [MAINTAINING.md](MAINTAINING.md).
