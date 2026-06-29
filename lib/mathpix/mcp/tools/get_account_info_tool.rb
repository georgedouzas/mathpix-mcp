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

            # Mathpix's v3 API has no account/plan endpoint for app tokens
            # (/v3/account returns 404). Derive the identifiers it does expose
            # from /v3/ocr-usage and tell the caller where to find plan/limits.
            rows = client.get('/ocr-usage', params: {})['ocr_usage'] || []
            first = rows.first || {}

            response_data = {
              success: true,
              account: {
                app_id: first['app_id'] || client.config.app_id,
                group_id: first['group_id']
              },
              note: 'Mathpix exposes no account/plan endpoint via the API; app_id/group_id are ' \
                    'derived from /v3/ocr-usage. View plan, limits, and billing in the Mathpix ' \
                    'console at https://console.mathpix.com.'
            }

            json_response(response_data)
          end
        end
      end
    end
  end
end
