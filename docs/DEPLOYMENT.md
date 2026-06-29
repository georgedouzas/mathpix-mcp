# Deploying the HTTP server

`mathpix-mcp-http` serves the MCP Streamable HTTP transport via Puma. Every
request must carry `Authorization: Bearer $MATHPIX_MCP_TOKEN`. By default it
binds to `127.0.0.1:3000` (override with `MATHPIX_MCP_HOST` / `MATHPIX_MCP_PORT`).

## Required environment

| Variable | Purpose |
|----------|---------|
| `MATHPIX_APP_ID`, `MATHPIX_APP_KEY` | Mathpix API credentials |
| `MATHPIX_MCP_TOKEN` | Bearer token clients must send (required) |
| `MATHPIX_MCP_HOST` | Bind address (default `127.0.0.1`; use `0.0.0.0` in containers) |
| `MATHPIX_MCP_PORT` | Bind port (default `3000`) |

Generate a token: `openssl rand -hex 32`. Store secrets in a secret manager or
an environment file with `chmod 600` — never commit them.

## Security checklist

- **Terminate TLS** in front of the server (reverse proxy). The bearer token is
  only as safe as the transport carrying it.
- Keep Puma bound to `127.0.0.1` (or a private interface) and let the proxy be
  the only public listener.
- Treat `MATHPIX_MCP_TOKEN` as a secret; rotate it; one token per client where
  practical.
- Put it behind your network's allow-list / VPN if it isn't meant to be public.

## Reverse proxy + TLS

### Caddy (automatic HTTPS)

```caddyfile
mcp.example.com {
    reverse_proxy 127.0.0.1:3000
}
```

### nginx

```nginx
server {
    listen 443 ssl;
    server_name mcp.example.com;

    ssl_certificate     /etc/letsencrypt/live/mcp.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mcp.example.com/privkey.pem;

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
        proxy_set_header   Authorization $http_authorization;
        # Streamable HTTP may use SSE responses — disable buffering:
        proxy_buffering    off;
        proxy_read_timeout 3600s;
    }
}
```

Clients then connect to `https://mcp.example.com/` with the bearer header.

## systemd (bare metal)

`/etc/systemd/system/mathpix-mcp.service`:

```ini
[Unit]
Description=Mathpix MCP HTTP server
After=network.target

[Service]
Type=simple
User=mathpix
WorkingDirectory=/opt/mathpix-mcp
EnvironmentFile=/etc/mathpix-mcp.env      # MATHPIX_APP_ID/KEY, MATHPIX_MCP_TOKEN, ...
ExecStart=/usr/local/bin/bundle exec mathpix-mcp-http
Restart=on-failure
# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

```bash
sudo chmod 600 /etc/mathpix-mcp.env
sudo systemctl daemon-reload
sudo systemctl enable --now mathpix-mcp
```

## Docker

A `Dockerfile` is included. Build and run:

```bash
docker build -t mathpix-mcp .

docker run --rm -p 3000:3000 \
  -e MATHPIX_APP_ID=... \
  -e MATHPIX_APP_KEY=... \
  -e MATHPIX_MCP_TOKEN=$(openssl rand -hex 32) \
  mathpix-mcp
```

The image sets `MATHPIX_MCP_HOST=0.0.0.0` so it accepts connections from the
host/proxy. Still terminate TLS at a proxy in front of the container.

### docker compose

```yaml
services:
  mathpix-mcp:
    build: .
    ports:
      - "127.0.0.1:3000:3000"   # expose only to localhost / your proxy
    environment:
      MATHPIX_APP_ID: ${MATHPIX_APP_ID}
      MATHPIX_APP_KEY: ${MATHPIX_APP_KEY}
      MATHPIX_MCP_TOKEN: ${MATHPIX_MCP_TOKEN}
    restart: unless-stopped
```

`docker compose up -d` (with the variables set in your shell or a `.env`).

## Smoke test

```bash
curl -s http://127.0.0.1:3000/ \
  -H "Authorization: Bearer $MATHPIX_MCP_TOKEN" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

A request without the header (or with a wrong token) must return `401`.
