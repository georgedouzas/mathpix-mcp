# Connecting agents / MCP clients

This server speaks MCP over **stdio** (`mathpix-mcp`) and **Streamable HTTP**
(`mathpix-mcp-http`, bearer-token auth). Below are configs for common clients.

In all examples replace credentials with your own and prefer a real secret for
`MATHPIX_MCP_TOKEN` (e.g. `openssl rand -hex 32`). Config schemas vary slightly
between client versions — check your client's docs if a key is rejected.

Assumes either the gem is installed (`gem install ./mathpix-mcp-*.gem`, giving
`mathpix-mcp` on PATH) or you run from a clone with `bundle exec`. The absolute
project path used below is `/Users/gdouzas/Projects/Personal/mathpix-mcp`.

---

## Claude Code (CLI)

**stdio** — keep secrets in the project `.env` and let the launcher `cd` in:

```bash
claude mcp add mathpix -- \
  bash -lc 'cd /Users/gdouzas/Projects/Personal/mathpix-mcp && exec bundle exec mathpix-mcp'
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

---

## Claude Desktop

Edit the config file:

- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

**stdio:**

```json
{
  "mcpServers": {
    "mathpix": {
      "command": "mathpix-mcp",
      "env": {
        "MATHPIX_APP_ID": "your_app_id",
        "MATHPIX_APP_KEY": "your_app_key"
      }
    }
  }
}
```

(Running from a clone instead of an installed gem: set `"command": "bundle"`,
`"args": ["exec", "mathpix-mcp"]`, and add `"BUNDLE_GEMFILE":
"/Users/gdouzas/Projects/Personal/mathpix-mcp/Gemfile"` to `env`.)

**HTTP:** Claude Desktop talks to local servers over stdio, so bridge to the
HTTP server with [`mcp-remote`](https://www.npmjs.com/package/mcp-remote):

```json
{
  "mcpServers": {
    "mathpix": {
      "command": "npx",
      "args": [
        "-y", "mcp-remote", "http://127.0.0.1:3000/",
        "--header", "Authorization: Bearer YOUR_TOKEN"
      ]
    }
  }
}
```

Restart Claude Desktop after editing.

---

## Codex (OpenAI Codex CLI)

Edit `~/.codex/config.toml`:

```toml
[mcp_servers.mathpix]
command = "mathpix-mcp"
env = { MATHPIX_APP_ID = "your_app_id", MATHPIX_APP_KEY = "your_app_key" }
```

From a clone instead of an installed gem:

```toml
[mcp_servers.mathpix]
command = "bundle"
args = ["exec", "mathpix-mcp"]
env = { BUNDLE_GEMFILE = "/Users/gdouzas/Projects/Personal/mathpix-mcp/Gemfile", MATHPIX_APP_ID = "...", MATHPIX_APP_KEY = "..." }
```

For HTTP, bridge with `mcp-remote`:

```toml
[mcp_servers.mathpix]
command = "npx"
args = ["-y", "mcp-remote", "http://127.0.0.1:3000/", "--header", "Authorization: Bearer YOUR_TOKEN"]
```

---

## Cursor

Edit `~/.cursor/mcp.json` (global) or `.cursor/mcp.json` (project).

**stdio:**

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

**HTTP** (Cursor supports remote URLs with headers):

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

---

## Any other MCP client (stdio-only) → HTTP

Use the `mcp-remote` bridge to connect a stdio-only client to the HTTP server:

```bash
npx -y mcp-remote http://127.0.0.1:3000/ --header "Authorization: Bearer YOUR_TOKEN"
```

VS Code (GitHub Copilot), Windsurf, Zed and others accept the same
`command`/`args`/`env` (stdio) or `url`/`headers` (HTTP) shapes shown above.
