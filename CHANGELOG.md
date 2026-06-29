# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Streamable HTTP transport** (`bin/mathpix-mcp-http` / `config.ru`) using the
  SDK's `StreamableHTTPTransport`, guarded by a required bearer token
  (`MATHPIX_MCP_TOKEN`); binds to `127.0.0.1` by default.
- Dev tooling: RuboCop (+ rake/rspec plugins), RSpec suite, Rakefile default
  task, and GitHub Actions CI (rubocop + rspec + bundler-audit).
- Docs: `docs/CLIENTS.md` (Claude Code/Desktop, Codex, Cursor, Gemini CLI,
  VS Code/Copilot, Windsurf, Zed, Continue, Cline, Goose, agent SDKs, generic
  bridge) and `docs/DEPLOYMENT.md` (TLS proxy, systemd, Docker); `Dockerfile` +
  `.dockerignore`.
- CD: `.github/workflows/release.yml` (build/publish gem + push Docker image to
  GHCR on `v*` tags); Dependabot; CODEOWNERS; PR template; `CONTRIBUTING.md`;
  `scripts/setup-branch-protection.sh`.

### Changed
- Upgraded `mcp` to a patched release (fixes CVE-2026-33946, SSE session
  binding) and updated the stdio transport require/path accordingly.
- Require `puma >= 8.0.2` (fixes CVE-2026-47736 / -47737, PROXY-protocol DoS).

## [0.1.0] - 2026-06-29

Initial release: a stdio Model Context Protocol server for Mathpix OCR.

### Added
- Nine MCP tools: `convert_document`, `convert_image`, `convert_strokes`,
  `batch_convert`, `check_document_status`, `search_results`, `get_usage`,
  `get_account_info`, `list_formats`.
- Document conversion (PDF/DOCX/PPTX) via `/v3/pdf`, supporting both remote URLs
  and local files (multipart upload), returning Markdown/HTML.
- `output_path` plus an automatic save-to-file fallback for large results, so
  conversions don't overflow the model context.
- Descriptive API errors that surface Mathpix's `error_info.message`.
- Concurrent `batch_convert` (bounded thread pool), size-guarded
  `search_results`, and polling that tolerates all intermediate Mathpix states.

### Dependencies
- Runtime: `base64`, `mcp`.
