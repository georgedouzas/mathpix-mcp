# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-06-29

First release: a Model Context Protocol server for Mathpix OCR over **stdio** and
**Streamable HTTP**, with every tool verified end-to-end against the live Mathpix
API.

### Added
- Nine MCP tools: `convert_document`, `convert_image`, `convert_strokes`,
  `batch_convert`, `check_document_status`, `search_results`, `get_usage`,
  `get_account_info`, `list_formats`.
- Document conversion (PDF/DOCX/PPTX) via `/v3/pdf` for remote URLs and local
  files (multipart upload), returning Markdown/HTML.
- Image OCR via `/v3/text`, handwritten strokes via `/v3/strokes`, and recent
  captures via `/v3/ocr-results`; usage/account identifiers via `/v3/ocr-usage`.
- File-routed output: OCR results (LaTeX/text/MathML/HTML/bounding-box data) are
  always written to files and returned as a path + short preview + metadata, so
  results never overflow the model context. Destination follows the tool's
  `output_path`/`output_dir`, else `MATHPIX_OUTPUT_DIR`, else the system temp dir.
- Descriptive API errors that surface Mathpix's `error_info.message` (status and
  details included).
- Concurrent `batch_convert` (bounded thread pool) and polling that tolerates all
  intermediate Mathpix states.
- stdio transport (`mathpix-mcp`) and Streamable HTTP transport
  (`mathpix-mcp-http` / `config.ru`) with required bearer-token auth
  (`MATHPIX_MCP_TOKEN`).
- Configuration via environment variables (documented in the README and
  `.env.example`), including `MATHPIX_OUTPUT_DIR` for the output directory.
- Docs: README with an env-var reference and per-agent client setup,
  `docs/DEPLOYMENT.md` for HTTP deployment, `MAINTAINING.md` for release/admin,
  and a `Dockerfile`.
- Tooling/CI: RuboCop + RSpec (`rake`), GitHub Actions CI (rubocop, rspec,
  bundler-audit), Dependabot, and a trusted-publishing release workflow.

### Dependencies
- Runtime: `base64`, `mcp` (>= 0.9.2), `rack`, `puma` (>= 8.0.2).
