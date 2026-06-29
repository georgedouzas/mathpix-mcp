# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
