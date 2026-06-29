# frozen_string_literal: true

require_relative '../base_tool'

module Mathpix
  module MCP
    module Tools
      # Get Usage Tool
      #
      # Retrieves API usage statistics and account limits
      # Thin delegate to Mathpix::Client (usage endpoint)
      class GetUsageTool < BaseTool
        description 'Get Mathpix API usage statistics and remaining credits'

        input_schema(
          properties: {
            detailed: {
              type: 'boolean',
              description: 'Include detailed breakdown by operation type (default: false)'
            }
          },
          required: []
        )

        def self.call(server_context:, detailed: false)
          safe_execute do
            client = mathpix_client(server_context)

            begin
              # Try to call the usage endpoint
              usage_data = client.get('/usage')

              response_data = {
                success: true,
                usage: {
                  requests_this_month: usage_data['requests_this_month'],
                  requests_remaining: usage_data['requests_remaining'],
                  plan: usage_data['plan'],
                  reset_date: usage_data['reset_date']
                }
              }

              response_data[:breakdown] = usage_data['breakdown'] if detailed && usage_data['breakdown']

              json_response(response_data)
            rescue Mathpix::APIError => e
              # Handle API-specific errors properly
              error_response(e)
            rescue StandardError => e
              # Handle unexpected errors
              error_response(e)
            end
          end
        end
      end
    end
  end
end
