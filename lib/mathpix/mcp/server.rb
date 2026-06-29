# frozen_string_literal: true

begin
  require 'mcp'
  require 'mcp/server/transports/stdio_transport' # transport not auto-loaded
rescue LoadError
  raise LoadError, <<~ERROR
    The 'mcp' gem is required for MCP server functionality.

    Add to your Gemfile:
      gem 'mcp'

    Or install directly:
      gem install mcp

    Official Ruby MCP SDK: https://github.com/modelcontextprotocol/ruby-sdk
  ERROR
end

module Mathpix
  module MCP
    # MCP Server for Mathpix OCR.
    #
    # Uses the official Ruby MCP SDK. Provides 9 tools as thin delegates to
    # Mathpix::Client over the stdio transport.
    #
    # @example Start STDIO server
    #   require 'mathpix/mcp'
    #
    #   Mathpix.configure do |config|
    #     config.app_id = ENV['MATHPIX_APP_ID']
    #     config.app_key = ENV['MATHPIX_APP_KEY']
    #   end
    #
    #   Mathpix::MCP::Server.run
    #
    # @example With custom configuration
    #   server = Mathpix::MCP::Server.new(
    #     name: "mathpix-custom",
    #     version: "1.0.0",
    #     mathpix_client: custom_client
    #   )
    #   transport = server.create_stdio_transport
    #   transport.open
    class Server
      attr_reader :name, :version, :mathpix_client, :mcp_server

      # Initialize MCP server
      #
      # @param name [String] server name
      # @param version [String] server version
      # @param mathpix_client [Mathpix::Client] optional client instance
      def initialize(name: 'mathpix', version: Mathpix::VERSION, mathpix_client: nil)
        @name = name
        @version = version
        @mathpix_client = mathpix_client || Mathpix.client
        @mcp_server = create_mcp_server
      end

      # Create STDIO transport (standard MCP transport)
      #
      # @return [::MCP::Server::Transports::StdioTransport]
      def create_stdio_transport
        ::MCP::Server::Transports::StdioTransport.new(@mcp_server)
      end

      # Run MCP server with STDIO transport (blocking)
      #
      # Standard way to run MCP server via stdio
      def run
        transport = create_stdio_transport
        transport.open
      end

      # Server capabilities
      #
      # @return [Hash] MCP server capabilities
      def capabilities
        {
          tools: tool_classes.map(&:name)
        }
      end

      # Class method: run server directly
      #
      # @example
      #   Mathpix::MCP::Server.run
      def self.run(**)
        new(**).run
      end

      private

      # Create the official MCP::Server with the tool classes
      #
      # Uses official Ruby MCP SDK structure
      def create_mcp_server
        ::MCP::Server.new(
          name: @name,
          version: @version,
          tools: tool_classes,
          server_context: { mathpix_client: @mathpix_client }
        )
      end

      # List of all tool classes (using official MCP::Tool)
      #
      # @return [Array<Class>] tool classes
      def tool_classes
        [
          Tools::ConvertImageTool,
          Tools::ConvertDocumentTool,
          Tools::ConvertStrokesTool,
          Tools::BatchConvertTool,
          Tools::CheckDocumentStatusTool,
          Tools::SearchResultsTool,
          Tools::GetUsageTool,
          Tools::GetAccountInfoTool,
          Tools::ListFormatsTool
        ]
      end
    end
  end
end
