# mathpix-mcp

A **Model Context Protocol server** for [Mathpix](https://mathpix.com) OCR, over
**stdio** or **Streamable HTTP** (bearer-token auth). It exposes Mathpix
conversion as MCP tools so an LLM/agent can turn images and PDF/DOCX/PPTX
documents into LaTeX and Markdown.

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

From RubyGems (provides the `mathpix-mcp` / `mathpix-mcp-http` executables):

```bash
gem install mathpix-mcp
```

Or straight from GitHub (in a Gemfile):

```ruby
gem 'mathpix-mcp', git: 'https://github.com/georgedouzas/mathpix-mcp'
```

Or build locally from a clone:

```bash
gem build mathpix-mcp.gemspec
gem install ./mathpix-mcp-*.gem
```

Or run from a clone with Bundler:

```bash
bundle install
cp .env.example .env                 # add your MATHPIX_APP_ID / MATHPIX_APP_KEY
```

## Run (stdio)

```bash
mathpix-mcp            # if installed as a gem
# or
bundle exec mathpix-mcp
```

It speaks MCP over stdio. Credentials are read from `.env` (when launched from
the project directory) or the process environment.

## Run (HTTP / Streamable HTTP)

The HTTP transport requires a bearer token (`MATHPIX_MCP_TOKEN`) — every request
must send `Authorization: Bearer <token>`. It binds to `127.0.0.1:3000` by
default (`MATHPIX_MCP_HOST` / `MATHPIX_MCP_PORT`).

```bash
export MATHPIX_MCP_TOKEN=$(openssl rand -hex 32)
mathpix-mcp-http                 # if installed as a gem
# or
bundle exec mathpix-mcp-http
# or, with a Rack server of your choice:
bundle exec puma config.ru -b tcp://127.0.0.1:3000
```

Example request:

```bash
curl -s http://127.0.0.1:3000/ \
  -H "Authorization: Bearer $MATHPIX_MCP_TOKEN" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

Don't expose it on a public interface without a TLS-terminating reverse proxy.

## Connect an agent

Per-client setup for both stdio and HTTP is in
**[docs/CLIENTS.md](docs/CLIENTS.md)** — covering Claude Code, Claude Desktop,
Codex, Cursor, Gemini CLI, VS Code (Copilot), Windsurf, Zed, Continue, Cline,
Goose, agent SDKs, and a generic `mcp-remote` bridge for anything else.

Quickest path — Claude Code over stdio:

```bash
claude mcp add mathpix -e MATHPIX_APP_ID=... -e MATHPIX_APP_KEY=... -- mathpix-mcp
```

## Deploy (HTTP)

Production deployment — TLS reverse proxy (Caddy/nginx), systemd, Docker /
docker-compose, and the security checklist — is in
**[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)**. A `Dockerfile` is included:

```bash
docker build -t mathpix-mcp .
docker run --rm -p 3000:3000 \
  -e MATHPIX_APP_ID=... -e MATHPIX_APP_KEY=... \
  -e MATHPIX_MCP_TOKEN=$(openssl rand -hex 32) mathpix-mcp
```

## Notes

- If Mathpix's backend rejects a malformed PDF (e.g. a `pdftoppm` crash), the
  tool returns a descriptive error; repairing the PDF first
  (`gs -o fixed.pdf -sDEVICE=pdfwrite in.pdf`) usually resolves it.

## License

MIT — see [LICENSE](LICENSE).
