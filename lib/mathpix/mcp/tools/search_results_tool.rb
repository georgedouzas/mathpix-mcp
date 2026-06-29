# frozen_string_literal: true

require_relative '../base_tool'

module Mathpix
  module MCP
    module Tools
      # Search Results Tool
      #
      # Searches recent capture results with optional filtering
      # Thin delegate to Mathpix::Client#recent with search
      class SearchResultsTool < BaseTool
        description 'Search recent Mathpix capture results with optional text filtering'

        input_schema(
          properties: {
            query: {
              type: 'string',
              description: 'Search query to filter results by LaTeX or text content'
            },
            limit: {
              type: 'number',
              description: 'Maximum number of results to return (default: 10, max: 100)'
            },
            offset: {
              type: 'number',
              description: 'Offset for pagination (default: 0)'
            },
            include_content: {
              type: 'boolean',
              description: 'Write each result\'s full LaTeX/text to a file and return its path ' \
                           '(default: false, previews only). Content is never returned inline.'
            },
            output_dir: {
              type: 'string',
              description: 'Directory for files written when include_content is true; defaults to ' \
                           'MATHPIX_OUTPUT_DIR or the system temp dir.'
            }
          },
          required: []
        )

        def self.call(server_context:, query: nil, limit: 10, offset: 0, include_content: false, output_dir: nil)
          safe_execute do
            client = mathpix_client(server_context)
            dir = output_dir && !output_dir.empty? ? File.expand_path(output_dir) : artifact_dir

            # Validate and constrain limit
            limit = [[limit.to_i, 1].max, 100].min

            # Get recent results from API
            recent_results = client.recent(limit: limit + offset)

            # Apply offset
            results = recent_results.drop(offset)

            # Apply search filter if query provided
            if query && !query.empty?
              query_lower = query.downcase
              results = results.select do |result|
                result.latex&.downcase&.include?(query_lower) ||
                  result.text&.downcase&.include?(query_lower)
              end
            end

            # Limit after filtering
            results = results.take(limit)

            # Format results. Previews are always inline; full content (when
            # requested) is written to a file so it never enters the context.
            formatted_results = results.each_with_index.map do |result, index|
              item = {
                id: result.request_id,
                created_at: result.timestamp,
                confidence: result.confidence,
                is_printed: result.printed?,
                is_handwritten: result.handwritten?,
                latex_preview: truncate(result.latex, 100),
                text_preview: truncate(result.text, 100)
              }

              if include_content
                contents = { 'latex' => result.latex, 'text' => result.text }.compact
                unless contents.empty?
                  stem = result.request_id || "result_#{offset + index}"
                  item[:saved_files] = write_artifacts(contents, File.join(dir, "mathpix_#{sanitize(stem)}.tex"))
                end
              end

              item
            end

            # Format response
            response_data = {
              success: true,
              query: query,
              limit: limit,
              offset: offset,
              count: formatted_results.length,
              results: formatted_results
            }

            json_response(response_data)
          end
        end

        def self.truncate(text, max_length)
          return nil unless text
          return text if text.length <= max_length

          "#{text[0...max_length]}..."
        end
      end
    end
  end
end
