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

        # Above this many characters of inlined content, downgrade to previews
        # so a large include_content response can't overflow the model context.
        MAX_INLINE_CONTENT_CHARS = 50_000

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
              description: 'Include full LaTeX/text content in results (default: false)'
            }
          },
          required: []
        )

        def self.call(server_context:, query: nil, limit: 10, offset: 0, include_content: false)
          safe_execute do
            client = mathpix_client(server_context)

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

            # Format results
            formatted_results = results.map do |result|
              item = {
                id: result.request_id,
                created_at: result.timestamp,
                confidence: result.confidence,
                is_printed: result.printed?,
                is_handwritten: result.handwritten?
              }

              # Include content if requested
              if include_content
                item[:latex] = result.latex
                item[:text] = result.text
              else
                # Just include preview
                item[:latex_preview] = truncate(result.latex, 100)
                item[:text_preview] = truncate(result.text, 100)
              end

              item
            end

            # Guard against overflowing the model context: if full content was
            # requested but it's too large, downgrade to previews + a note.
            note = nil
            if include_content
              content_chars = formatted_results.sum { |i| i[:latex].to_s.length + i[:text].to_s.length }
              if content_chars > MAX_INLINE_CONTENT_CHARS
                formatted_results.each do |item|
                  item[:latex_preview] = truncate(item.delete(:latex), 100)
                  item[:text_preview] = truncate(item.delete(:text), 100)
                end
                note = "Full content (#{content_chars} chars) exceeded the inline limit " \
                       "(#{MAX_INLINE_CONTENT_CHARS}); returning previews instead. Narrow the " \
                       'query or lower limit to retrieve full content.'
              end
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
            response_data[:note] = note if note

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
