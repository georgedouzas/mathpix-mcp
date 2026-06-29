# frozen_string_literal: true

require 'json'
require 'rack'
require 'mcp/server/transports/streamable_http_transport'

module Mathpix
  module MCP
    # Builds a Rack application that serves the Mathpix MCP server over the
    # MCP Streamable HTTP transport, guarded by a bearer token.
    #
    # @example config.ru
    #   require 'mathpix/mcp/http_app'
    #   run Mathpix::MCP::HttpApp.build
    module HttpApp
      module_function

      # Build the bearer-guarded Rack app.
      #
      # @param token [String] required bearer token (defaults to MATHPIX_MCP_TOKEN)
      # @param server [Mathpix::MCP::Server] optional pre-built server
      # @return [#call] a Rack application
      # @raise [RuntimeError] if no token is configured
      def build(token: ENV.fetch('MATHPIX_MCP_TOKEN', nil), server: nil)
        raise 'MATHPIX_MCP_TOKEN must be set to run the HTTP transport (bearer-token auth is required)' if token.nil? || token.empty?

        mcp_server = (server || Mathpix::MCP::Server.new).mcp_server
        # stateless + JSON responses keep this simple and sidestep session
        # state entirely; bearer auth guards every request.
        transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(
          mcp_server, stateless: true, enable_json_response: true
        )
        BearerAuth.new(transport, token: token)
      end

      # Rack middleware enforcing a constant-time bearer-token check.
      class BearerAuth
        def initialize(app, token:)
          @app = app
          @token = token
        end

        def call(env)
          provided = env['HTTP_AUTHORIZATION'].to_s.sub(/\ABearer\s+/i, '')
          return unauthorized unless Rack::Utils.secure_compare(@token, provided)

          @app.call(env)
        end

        private

        def unauthorized
          [401,
           { 'content-type' => 'application/json' },
           [JSON.generate(error: true, message: 'Unauthorized: missing or invalid bearer token')]]
        end
      end
    end
  end
end
