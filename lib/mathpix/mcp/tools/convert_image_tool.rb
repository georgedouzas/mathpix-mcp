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
            },
            output_path: {
              type: 'string',
              description: 'Where to write the OCR result. The recognized content is always ' \
                           'saved to a file (never returned inline); defaults to MATHPIX_OUTPUT_DIR ' \
                           'or the system temp dir.'
            }
          },
          required: ['image_path']
        )

        def self.call(image_path:, server_context:, formats: nil, include_line_data: false, include_word_data: false,
                      confidence_threshold: nil, output_path: nil)
          safe_execute do
            client = mathpix_client(server_context)

            # Normalize path (expand ~, resolve relative paths)
            image_path = normalize_path(image_path) unless url?(image_path)

            # Extract formats or use defaults
            output_formats = extract_formats(formats, client)

            # Delegate to core gem
            result = client.snap(image_path,
                                 **snap_options(output_formats, include_line_data, include_word_data,
                                                confidence_threshold))

            # Write recognized content (and any requested bounding-box data) to
            # files so it never enters the model context.
            contents = artifact_contents(result, include_line_data, include_word_data)
            stem = url?(image_path) ? 'image' : File.basename(image_path, File.extname(image_path))
            base = output_path && !output_path.empty? ? output_path : default_artifact_path(stem, 'tex')

            json_response(
              success: true,
              image_path: image_path,
              formats: output_formats,
              confidence: result.confidence,
              is_printed: result.printed?,
              is_handwritten: result.handwritten?,
              saved_files: write_artifacts(contents, base),
              preview: preview_of(result.latex || result.text)
            )
          end
        end

        # Build the options hash passed to Client#snap.
        def self.snap_options(formats, include_line_data, include_word_data, confidence_threshold)
          options = { formats: formats }
          options[:include_line_data] = true if include_line_data
          options[:include_word_data] = true if include_word_data
          options[:confidence_threshold] = confidence_threshold if confidence_threshold
          options
        end

        # Available OCR formats (and optional bounding-box data) as a
        # format => content hash.
        def self.artifact_contents(result, include_line_data, include_word_data)
          contents = {
            'latex' => result.latex,
            'text' => result.text,
            'mathml' => result.mathml,
            'asciimath' => result.asciimath
          }.compact
          contents['line_data'] = result.line_data if include_line_data && !result.line_data.empty?
          contents['word_data'] = result.word_data if include_word_data && !result.word_data.empty?
          contents
        end
      end
    end
  end
end
