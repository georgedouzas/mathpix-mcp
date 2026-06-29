# mathpix-mcp

A **Model Context Protocol server** for [Mathpix](https://mathpix.com) OCR, over
**stdio** or **Streamable HTTP** (bearer-token auth). It exposes Mathpix
conversion as MCP tools so an LLM/agent can turn images and PDF/DOCX/PPTX
documents into LaTeX and Markdown.

## Tools

| Tool | Purpose |
|------|---------|
| `convert_document_tool` | PDF/DOCX/PPTX → Markdown/LaTeX/HTML (URL or local path). Saves output to a file and returns a path + preview so it doesn't overflow the model context. |
| `convert_image_tool` | Image → LaTeX/text/MathML/etc. Result is written to a file (path + preview returned). |
| `convert_strokes_tool` | Handwritten strokes → LaTeX/text. |
| `batch_convert_tool` | Multiple images, optionally concurrent (`parallel`, `max_parallel`). |
| `check_document_status_tool` | Poll an async document conversion. |
| `search_results_tool` | Search recent captures; full content (when requested) is written to files. |
| `get_usage_tool` / `get_account_info_tool` | Usage statistics and account identifiers. |
| `list_formats_tool` | List supported output formats. |

> OCR results (LaTeX/text/MathML/etc.) are always written to files rather than
> returned inline; tools return a file path, a short preview, and metadata. The
> destination follows the tool's `output_path`/`output_dir` argument, else
> `MATHPIX_OUTPUT_DIR`, else the system temp dir.

## Requirements

- Ruby >= 3.2 (CI runs 3.3 and 3.4)
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

## Configuration

All configuration is via environment variables (loaded from `.env` when launched
from the project directory, or from the process environment). Copy
[`.env.example`](.env.example) to `.env` as a starting point.

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MATHPIX_APP_ID` | **yes** | — | Mathpix application id. |
| `MATHPIX_APP_KEY` | **yes** | — | Mathpix application key. |
| `MATHPIX_OUTPUT_DIR` | no | system temp dir | Where OCR results are written when a tool isn't given an explicit `output_path`/`output_dir`. |
| `MATHPIX_MAX_FILE_SIZE_MB` | no | `10` | Maximum local file size accepted for upload. |
| `MATHPIX_HTTPS_ONLY` | no | `true` | Upgrade/enforce HTTPS for remote sources. |
| `MATHPIX_API_URL` | no | `https://api.mathpix.com/v3` | Mathpix API base URL. |
| `MATHPIX_TIMEOUT` | no | `30` | Per-request timeout in seconds (1–300). |
| `MATHPIX_LOG_LEVEL` | no | _(off)_ | Log verbosity to stderr: `DEBUG`/`INFO`/`WARN`/`ERROR`. |
| `MATHPIX_MCP_TOKEN` | HTTP only | — | Bearer token required by the HTTP transport. |
| `MATHPIX_MCP_HOST` | no | `127.0.0.1` | HTTP bind host. |
| `MATHPIX_MCP_PORT` | no | `3000` | HTTP bind port. |

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

This server speaks MCP over **stdio** (`mathpix-mcp`) and **Streamable HTTP**
(`mathpix-mcp-http`, bearer-token auth). Replace credentials with your own and
prefer a real secret for `MATHPIX_MCP_TOKEN` (e.g. `openssl rand -hex 32`).
Config schemas vary slightly between client versions — check your client's docs
if a key is rejected. Examples assume the gem is installed (`mathpix-mcp` on
`PATH`); to run from a clone, use `bundle` as the command with
`args: ["exec", "mathpix-mcp"]` and set `BUNDLE_GEMFILE` to the project's
`Gemfile`.

### Claude Code (CLI)

**stdio** — keep secrets in the project `.env` and let the launcher `cd` in:

```bash
claude mcp add mathpix -- \
  bash -lc 'cd /path/to/mathpix-mcp && exec bundle exec mathpix-mcp'
```

or, if installed as a gem, pass creds inline:

```bash
claude mcp add mathpix -e MATHPIX_APP_ID=... -e MATHPIX_APP_KEY=... -- mathpix-mcp
```

**HTTP** — point at a running `mathpix-mcp-http`:

```bash
claude mcp add --transport http mathpix http://127.0.0.1:3000/ \
  --header "Authorization: Bearer $MATHPIX_MCP_TOKEN"
```

List/verify: `claude mcp list`.

<details>
<summary><b>Claude Desktop</b></summary>

Edit the config file (macOS:
`~/Library/Application Support/Claude/claude_desktop_config.json`, Windows:
`%APPDATA%\Claude\claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "mathpix": {
      "command": "mathpix-mcp",
      "env": { "MATHPIX_APP_ID": "your_app_id", "MATHPIX_APP_KEY": "your_app_key" }
    }
  }
}
```

Claude Desktop talks to local servers over stdio, so for HTTP bridge with
[`mcp-remote`](https://www.npmjs.com/package/mcp-remote):

```json
{
  "mcpServers": {
    "mathpix": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://127.0.0.1:3000/",
               "--header", "Authorization: Bearer YOUR_TOKEN"]
    }
  }
}
```

Restart Claude Desktop after editing.
</details>

<details>
<summary><b>Codex (OpenAI Codex CLI)</b></summary>

Edit `~/.codex/config.toml`:

```toml
[mcp_servers.mathpix]
command = "mathpix-mcp"
env = { MATHPIX_APP_ID = "your_app_id", MATHPIX_APP_KEY = "your_app_key" }
```

For HTTP, bridge with `mcp-remote`:

```toml
[mcp_servers.mathpix]
command = "npx"
args = ["-y", "mcp-remote", "http://127.0.0.1:3000/", "--header", "Authorization: Bearer YOUR_TOKEN"]
```
</details>

<details>
<summary><b>Cursor</b></summary>

Edit `~/.cursor/mcp.json` (global) or `.cursor/mcp.json` (project).

```json
{
  "mcpServers": {
    "mathpix": {
      "command": "mathpix-mcp",
      "env": { "MATHPIX_APP_ID": "your_app_id", "MATHPIX_APP_KEY": "your_app_key" }
    }
  }
}
```

HTTP (Cursor supports remote URLs with headers):

```json
{
  "mcpServers": {
    "mathpix": {
      "url": "http://127.0.0.1:3000/",
      "headers": { "Authorization": "Bearer YOUR_TOKEN" }
    }
  }
}
```
</details>

<details>
<summary><b>Gemini CLI</b></summary>

Edit `~/.gemini/settings.json`:

```json
{
  "mcpServers": {
    "mathpix": {
      "command": "mathpix-mcp",
      "env": { "MATHPIX_APP_ID": "your_app_id", "MATHPIX_APP_KEY": "your_app_key" }
    }
  }
}
```

HTTP (Gemini CLI uses `httpUrl` for Streamable HTTP; `url` for SSE):

```json
{
  "mcpServers": {
    "mathpix": {
      "httpUrl": "http://127.0.0.1:3000/",
      "headers": { "Authorization": "Bearer YOUR_TOKEN" }
    }
  }
}
```
</details>

<details>
<summary><b>VS Code (GitHub Copilot, agent mode)</b></summary>

Create `.vscode/mcp.json` in the workspace (top-level key is `servers`):

```json
{
  "servers": {
    "mathpix": {
      "type": "stdio",
      "command": "mathpix-mcp",
      "env": { "MATHPIX_APP_ID": "your_app_id", "MATHPIX_APP_KEY": "your_app_key" }
    }
  }
}
```

HTTP — use `"type": "http"`, `"url": "http://127.0.0.1:3000/"`, and a `headers`
object with the bearer token.
</details>

<details>
<summary><b>Windsurf</b></summary>

Edit `~/.codeium/windsurf/mcp_config.json`:

```json
{
  "mcpServers": {
    "mathpix": {
      "command": "mathpix-mcp",
      "env": { "MATHPIX_APP_ID": "your_app_id", "MATHPIX_APP_KEY": "your_app_key" }
    }
  }
}
```

HTTP uses `serverUrl`:
`{ "mcpServers": { "mathpix": { "serverUrl": "http://127.0.0.1:3000/" } } }`. If
your version can't attach the bearer header, use the `mcp-remote` bridge as the
`command`.
</details>

<details>
<summary><b>Zed</b></summary>

Edit `settings.json` (`Cmd/Ctrl+,`) under `context_servers`:

```json
{
  "context_servers": {
    "mathpix": {
      "command": {
        "path": "mathpix-mcp",
        "args": [],
        "env": { "MATHPIX_APP_ID": "your_app_id", "MATHPIX_APP_KEY": "your_app_key" }
      }
    }
  }
}
```
</details>

<details>
<summary><b>Continue, Cline, Goose</b></summary>

**Continue** (`~/.continue/config.yaml`):

```yaml
mcpServers:
  - name: Mathpix
    command: mathpix-mcp
    env:
      MATHPIX_APP_ID: your_app_id
      MATHPIX_APP_KEY: your_app_key
```

**Cline** (MCP Servers panel → "Configure MCP Servers" →
`cline_mcp_settings.json`): same `mcpServers` JSON shape as Cursor.

**Goose** (`~/.config/goose/config.yaml`):

```yaml
extensions:
  mathpix:
    enabled: true
    type: stdio
    cmd: mathpix-mcp
    args: []
    envs:
      MATHPIX_APP_ID: your_app_id
      MATHPIX_APP_KEY: your_app_key
```
</details>

<details>
<summary><b>Programmatic (agent SDKs) &amp; any other client</b></summary>

For HTTP, point any MCP-capable SDK at `http://<host>:3000/` with an
`Authorization: Bearer <token>` header — e.g. the Anthropic Claude Agent SDK MCP
connector, the OpenAI Agents SDK (`MCPServerStreamableHttp`), or LangChain's MCP
adapters. For stdio, spawn `mathpix-mcp` with `MATHPIX_APP_ID` /
`MATHPIX_APP_KEY` in its environment.

Most clients use one of two shapes: **stdio** (`command` + `args` + `env`) or
**HTTP** (a URL field — `url`/`httpUrl`/`serverUrl`, name varies — plus
`headers`). If a stdio-only client can't reach the HTTP server, bridge with
[`mcp-remote`](https://www.npmjs.com/package/mcp-remote):

```bash
npx -y mcp-remote http://127.0.0.1:3000/ --header "Authorization: Bearer YOUR_TOKEN"
```
</details>

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
