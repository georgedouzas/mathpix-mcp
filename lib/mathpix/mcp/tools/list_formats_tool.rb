# frozen_string_literal: true

require_relative '../base_tool'

module Mathpix
  module MCP
    module Tools
      # List Formats Tool
      #
      # Lists all available output formats for Mathpix OCR
      # Static data from API documentation
      class ListFormatsTool < BaseTool
        description 'List all available output formats for Mathpix OCR operations'

        input_schema(
          properties: {
            category: {
              type: 'string',
              description: 'Filter by category: image, document, or all (default: all)',
              enum: %w[image document all]
            }
          },
          required: []
        )

        def self.call(server_context:, category: 'all')
          safe_execute do
            # Static format definitions
            image_formats = [
              { name: 'latex_styled', description: 'LaTeX with styling', type: 'image' },
              { name: 'text', description: 'Plain text', type: 'image' },
              { name: 'latex_list', description: 'Array of LaTeX expressions', type: 'image' },
              { name: 'mathml', description: 'MathML markup', type: 'image' },
              { name: 'asciimath', description: 'AsciiMath notation', type: 'image' },
              { name: 'text_display', description: 'Display-style text', type: 'image' },
              { name: 'latex_simplified', description: 'Simplified LaTeX', type: 'image' },
              { name: 'data', description: 'Full response data with metadata', type: 'image' },
              { name: 'html', description: 'HTML markup', type: 'image' }
            ]

            document_formats = [
              { name: 'markdown', description: 'Markdown format', type: 'document' },
              { name: 'latex', description: 'LaTeX document', type: 'document' },
              { name: 'html', description: 'HTML document', type: 'document' },
              { name: 'docx', description: 'Microsoft Word document', type: 'document' },
              { name: 'tex.zip', description: 'LaTeX with figures (zipped)', type: 'document' }
            ]

            # Filter by category
            formats = case category
                      when 'image'
                        image_formats
                      when 'document'
                        document_formats
                      when 'all'
                        image_formats + document_formats
                      else
                        image_formats + document_formats
                      end

            # Format response
            response_data = {
              success: true,
              category: category,
              count: formats.length,
              formats: formats,
              usage: {
                image_capture: 'Use with snap() or ConvertImageTool',
                document_conversion: 'Use with document() or ConvertDocumentTool'
              }
            }

            json_response(response_data)
          end
        end
      end
    end
  end
end
