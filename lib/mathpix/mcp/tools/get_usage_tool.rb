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
            from_date: {
              type: 'string',
              description: 'ISO-8601 start date to report usage from (e.g. 2026-06-01T00:00:00.000Z). ' \
                           'Omit to use the Mathpix default window.'
            },
            detailed: {
              type: 'boolean',
              description: 'Include the raw per-request usage rows (default: false)'
            }
          },
          required: []
        )

        def self.call(server_context:, from_date: nil, detailed: false)
          safe_execute do
            client = mathpix_client(server_context)

            # Mathpix exposes usage at /v3/ocr-usage; there is no /v3/usage.
            params = {}
            params[:from_date] = from_date if from_date && !from_date.empty?
            usage_data = client.get('/ocr-usage', params: params)

            rows = usage_data['ocr_usage'] || []
            by_type = rows.each_with_object(Hash.new(0)) do |row, acc|
              acc[row['usage_type']] += row['count'] || 0
            end

            response_data = {
              success: true,
              usage: {
                app_id: rows.first&.fetch('app_id', nil),
                group_id: rows.first&.fetch('group_id', nil),
                total_requests: rows.sum { |row| row['count'] || 0 },
                by_usage_type: by_type
              }
            }
            response_data[:rows] = rows if detailed

            json_response(response_data)
          end
        end
      end
    end
  end
end
