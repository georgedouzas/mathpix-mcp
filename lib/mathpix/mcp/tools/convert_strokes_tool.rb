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
            },
            output_path: {
              type: 'string',
              description: 'Where to write the OCR result. The recognized content is always ' \
                           'saved to a file (never returned inline); defaults to MATHPIX_OUTPUT_DIR ' \
                           'or the system temp dir.'
            }
          },
          required: ['strokes']
        )

        def self.call(strokes:, server_context:, formats: nil, width: nil, height: nil, output_path: nil)
          safe_execute do
            client = mathpix_client(server_context)

            # Extract formats or use defaults
            output_formats = extract_formats(formats, client)

            # Delegate to the strokes endpoint (transposes points internally)
            options = { formats: output_formats }
            options[:width] = width if width
            options[:height] = height if height
            result = client.convert_strokes(strokes, **options)

            # Collect available formats and write them to disk so the recognized
            # content never enters the model context.
            contents = artifact_contents(result)
            base = output_path && !output_path.empty? ? output_path : default_artifact_path('strokes', 'tex')
            saved = write_artifacts(contents, base)

            response_data = {
              success: true,
              input_type: 'strokes',
              stroke_count: strokes.length,
              formats: output_formats,
              confidence: result.confidence,
              is_handwritten: result.handwritten?,
              saved_files: saved,
              preview: preview_of(result.latex || result.text)
            }

            json_response(response_data)
          end
        end

        # Available OCR formats as a format => content hash.
        def self.artifact_contents(result)
          {
            'latex' => result.latex,
            'text' => result.text,
            'mathml' => result.mathml,
            'asciimath' => result.asciimath
          }.compact
        end
      end
    end
  end
end
