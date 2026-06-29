# frozen_string_literal: true

module Mathpix
  module MCP
    module Tools
      # Base class for all Mathpix MCP tools
      #
      # Uses official Ruby MCP SDK (MCP::Tool)
      # Provides common utilities for Mathpix-specific tools
      #
      #
      # @example Tool implementation
      #   class ExampleTool < BaseTool
      #     description "Example tool"
      #     input_schema(
      #       properties: { message: { type: "string" } },
      #       required: ["message"]
      #     )
      #
      #     def self.call(message:, server_context:)
      #       client = server_context[:mathpix_client]
      #       # Use client to make API calls
      #       text_response("Result: #{message}")
      #     end
      #   end
      class BaseTool < ::MCP::Tool
        class << self
          protected

          # Get Mathpix client from server context
          #
          # @param server_context [Hash] MCP server context
          # @return [Mathpix::Client] Mathpix API client
          def mathpix_client(server_context)
            server_context[:mathpix_client] || raise(ArgumentError, 'mathpix_client not in server_context')
          end

          # Create text response (official MCP format)
          #
          # @param text [String] response text
          # @return [::MCP::Tool::Response]
          def text_response(text)
            ::MCP::Tool::Response.new([{
                                        type: 'text',
                                        text: text
                                      }])
          end

          # Create JSON response with text wrapper
          #
          # @param data [Hash] JSON data
          # @return [::MCP::Tool::Response]
          def json_response(data)
            text_response(JSON.pretty_generate(data))
          end

          # Create error response
          #
          # @param error [StandardError, String] error object or message
          # @return [::MCP::Tool::Response]
          def error_response(error)
            message = error.is_a?(StandardError) ? error.message : error.to_s
            details = error.is_a?(Mathpix::Error) ? error.details : {}

            error_data = {
              error: true,
              message: message,
              type: error.is_a?(StandardError) ? error.class.name : 'Error'
            }
            error_data[:status] = error.status if error.is_a?(Mathpix::APIError) && error.status
            error_data[:details] = details unless details.nil? || details.empty?

            json_response(error_data)
          end

          # Extract formats from arguments
          #
          # @param formats [Array, nil] format array
          # @param client [Mathpix::Client] client for defaults
          # @return [Array<Symbol>] format symbols
          def extract_formats(formats, client)
            return client.config.default_formats if formats.nil? || formats.empty?

            Array(formats).map(&:to_sym)
          end

          # Normalize path (expand ~, resolve relative paths)
          #
          # @param path [String] file path
          # @return [String] normalized path
          def normalize_path(path)
            File.expand_path(path)
          rescue StandardError
            path
          end

          # Check if path is a URL
          #
          # @param path [String] path or URL
          # @return [Boolean]
          def url?(path)
            path.to_s.start_with?('http://', 'https://')
          end

          # Safe execute with error handling
          #
          # @yield Block to execute
          # @return [::MCP::Tool::Response]
          def safe_execute
            yield
          rescue Mathpix::Error => e
            error_response(e)
          rescue StandardError => e
            error_response(e)
          end
        end
      end
    end
  end
end
