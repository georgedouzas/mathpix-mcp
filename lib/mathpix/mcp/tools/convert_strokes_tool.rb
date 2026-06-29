# frozen_string_literal: true

require_relative '../base_tool'

module Mathpix
  module MCP
    module Tools
      # Convert Strokes Tool
      #
      # Converts handwritten strokes to LaTeX, text, or other formats
      # Thin delegate to Mathpix::Client#snap with strokes format
      class ConvertStrokesTool < BaseTool
        description 'Convert handwritten strokes to LaTeX, text, or other formats using Mathpix OCR'

        input_schema(
          properties: {
            strokes: {
              type: 'array',
              items: {
                type: 'array',
                items: {
                  type: 'array',
                  items: { type: 'number' }
                }
              },
              description: 'Array of stroke arrays, where each stroke is an array of [x, y] coordinates'
            },
            formats: {
              type: 'array',
              items: { type: 'string' },
              description: 'Output formats: latex, text, mathml, asciimath (default: latex_styled, text)'
            },
            width: {
              type: 'number',
              description: 'Canvas width for stroke normalization'
            },
            height: {
              type: 'number',
              description: 'Canvas height for stroke normalization'
            }
          },
          required: ['strokes']
        )

        def self.call(strokes:, server_context:, formats: nil, width: nil, height: nil)
          safe_execute do
            client = mathpix_client(server_context)

            # Extract formats or use defaults
            output_formats = extract_formats(formats, client)

            # Build strokes data structure
            strokes_data = {
              strokes: strokes
            }
            strokes_data[:width] = width if width
            strokes_data[:height] = height if height

            # Delegate to core gem snap method with strokes
            result = client.snap(strokes_data, formats: output_formats)

            # Format response
            response_data = {
              success: true,
              input_type: 'strokes',
              stroke_count: strokes.length,
              formats: output_formats,
              results: {
                latex: result.latex,
                text: result.text,
                confidence: result.confidence,
                is_handwritten: result.handwritten?,
                position: result.position
              }
            }

            # Add optional formats
            response_data[:results][:mathml] = result.mathml if result.mathml
            response_data[:results][:asciimath] = result.asciimath if result.asciimath

            json_response(response_data)
          end
        end
      end
    end
  end
end
