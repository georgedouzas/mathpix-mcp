# mathpix-mcp

A **Model Context Protocol (stdio) server** for [Mathpix](https://mathpix.com) OCR.
It exposes Mathpix conversion as MCP tools so an LLM/agent can turn images and
PDF/DOCX/PPTX documents into LaTeX and Markdown.

## Tools

| Tool | Purpose |
|------|---------|
| `convert_document_tool` | PDF/DOCX/PPTX → Markdown/LaTeX/HTML (URL or local path). Supports `output_path` and auto-saves large output to a file so it doesn't overflow the model context. |
| `convert_image_tool` | Image → LaTeX/text/MathML/etc. |
| `convert_strokes_tool` | Handwritten strokes → LaTeX/text. |
| `batch_convert_tool` | Multiple images, optionally concurrent (`parallel`, `max_parallel`). |
| `check_document_status_tool` | Poll an async document conversion. |
| `search_results_tool` | Search recent captures (size-guarded). |
| `get_usage_tool` / `get_account_info_tool` | Account/usage info. |
| `list_formats_tool` | List supported output formats. |

## Requirements

- Ruby >= 3.2
- Mathpix API credentials (`MATHPIX_APP_ID`, `MATHPIX_APP_KEY`)

## Install

As a gem:

```bash
gem build mathpix-mcp.gemspec
gem install ./mathpix-mcp-*.gem      # provides the `mathpix-mcp` executable
```

Or from a clone, with Bundler:

```bash
bundle install
cp .env.example .env                 # add your MATHPIX_APP_ID / MATHPIX_APP_KEY
```

## Run

```bash
mathpix-mcp            # if installed as a gem
# or
bundle exec mathpix-mcp
```

It speaks MCP over stdio. Credentials are read from `.env` (when launched from
the project directory) or the process environment.

## Register as an MCP server (Claude Code)

Using a gem install (executable on PATH):

```bash
claude mcp add mathpix \
  -e MATHPIX_APP_ID=... -e MATHPIX_APP_KEY=... \
  -- mathpix-mcp
```

From a clone, keeping secrets in the project `.env`:

```bash
claude mcp add mathpix -- \
  bash -lc 'cd /Users/gdouzas/Projects/Personal/mathpix-mcp && exec bundle exec mathpix-mcp'
```

## Notes

- If Mathpix's backend rejects a malformed PDF (e.g. a `pdftoppm` crash), the
  tool returns a descriptive error; repairing the PDF first
  (`gs -o fixed.pdf -sDEVICE=pdfwrite in.pdf`) usually resolves it.

## License

MIT — see [LICENSE](LICENSE).
