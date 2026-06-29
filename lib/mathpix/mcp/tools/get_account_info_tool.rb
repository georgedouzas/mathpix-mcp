# frozen_string_literal: true

require_relative '../base_tool'

module Mathpix
  module MCP
    module Tools
      # Get Account Info Tool
      #
      # Retrieves account information and plan details
      # Thin delegate to Mathpix::Client (account endpoint)
      class GetAccountInfoTool < BaseTool
        description 'Get Mathpix account information, plan details, and limits'

        input_schema(
          properties: {},
          required: []
        )

        def self.call(server_context:)
          safe_execute do
            client = mathpix_client(server_context)

            begin
              # Try to call the account endpoint
              account_data = client.get('/account')

              response_data = {
                success: true,
                account: {
                  email: account_data['email'],
                  plan: account_data['plan'],
                  created_at: account_data['created_at'],
                  limits: {
                    monthly_requests: account_data['monthly_requests'],
                    max_file_size: account_data['max_file_size'],
                    features: account_data['features']
                  }
                }
              }

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
