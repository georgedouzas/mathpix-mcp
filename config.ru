# frozen_string_literal: true

# Rack entrypoint for the Mathpix MCP Streamable HTTP transport.
# Run with: bundle exec puma config.ru -b tcp://127.0.0.1:3000
#
# Requires MATHPIX_APP_ID, MATHPIX_APP_KEY and MATHPIX_MCP_TOKEN in the
# environment (or a local .env).

begin
  require 'dotenv/load'
rescue LoadError
  nil
end

require 'mathpix'
require 'mathpix/mcp'
require 'mathpix/mcp/http_app'

Mathpix.configure do |config|
  config.app_id = ENV.fetch('MATHPIX_APP_ID', nil)
  config.app_key = ENV.fetch('MATHPIX_APP_KEY', nil)
end

run Mathpix::MCP::HttpApp.build
