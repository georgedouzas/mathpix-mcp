# syntax=docker/dockerfile:1
FROM ruby:3.4-slim

# Build tools for native extensions (puma).
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install dependencies first (better layer caching). The gemspec evaluates
# lib/mathpix/version.rb, so copy it before bundling.
COPY Gemfile Gemfile.lock mathpix-mcp.gemspec ./
COPY lib/mathpix/version.rb lib/mathpix/version.rb
RUN bundle config set --local without 'development test' \
  && bundle install

# App source
COPY . .

# Accept connections from outside the container (put a TLS proxy in front).
ENV MATHPIX_MCP_HOST=0.0.0.0 \
    MATHPIX_MCP_PORT=3000
EXPOSE 3000

# MATHPIX_APP_ID / MATHPIX_APP_KEY / MATHPIX_MCP_TOKEN must be provided at run time.
CMD ["bundle", "exec", "mathpix-mcp-http"]
