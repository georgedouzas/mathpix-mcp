# frozen_string_literal: true

require_relative '../base_tool'

module Mathpix
  module MCP
    module Tools
      # Convert Image Tool
      #
      # Converts images (PNG, JPG, etc.) to LaTeX, text, or other formats
      # Thin delegate to Mathpix::Client#snap
      class ConvertImageTool < BaseTool
        description 'Convert image (PNG, JPG, etc.) to LaTeX, text, or other formats using Mathpix OCR'

        input_schema(
          properties: {
            image_path: {
              type: 'string',
              description: 'Path to image file or URL (http:// or https://)'
            },
            formats: {
              type: 'array',
              items: { type: 'string' },
              description: 'Output formats: latex, text, mathml, asciimath, latex_styled, text_display, data, html (default: latex_styled, text)'
            },
            include_line_data: {
              type: 'boolean',
              description: 'Include line-level bounding boxes in response'
            },
            include_word_data: {
              type: 'boolean',
              description: 'Include word-level bounding boxes in response'
            },
            confidence_threshold: {
              type: 'number',
              description: 'Minimum confidence threshold (0.0-1.0)'
            }
          },
          required: ['image_path']
        )

        def self.call(image_path:, server_context:, formats: nil, include_line_data: false, include_word_data: false,
                      confidence_threshold: nil)
          safe_execute do
            client = mathpix_client(server_context)

            # Normalize path (expand ~, resolve relative paths)
            image_path = normalize_path(image_path) unless url?(image_path)

            # Extract formats or use defaults
            output_formats = extract_formats(formats, client)

            # Build options
            options = {}
            options[:formats] = output_formats
            options[:include_line_data] = true if include_line_data
            options[:include_word_data] = true if include_word_data
            options[:confidence_threshold] = confidence_threshold if confidence_threshold

            # Delegate to core gem
            result = client.snap(image_path, **options)

            # Format response
            response_data = {
              success: true,
              image_path: image_path,
              formats: output_formats,
              results: {
                latex: result.latex,
                text: result.text,
                confidence: result.confidence,
                is_printed: result.printed?,
                is_handwritten: result.handwritten?,
                position: result.position
              }
            }

            # Add optional data
            response_data[:line_data] = result.line_data if include_line_data
            response_data[:word_data] = result.word_data if include_word_data
            response_data[:results][:mathml] = result.mathml if result.mathml
            response_data[:results][:asciimath] = result.asciimath if result.asciimath

            json_response(response_data)
          end
        end
      end
    end
  end
end
