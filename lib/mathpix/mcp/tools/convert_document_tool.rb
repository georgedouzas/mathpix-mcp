# frozen_string_literal: true

require 'tmpdir'
require_relative '../base_tool'

module Mathpix
  module MCP
    module Tools
      # Convert Document Tool
      #
      # Converts documents (PDF, DOCX, PPTX) to Markdown, LaTeX, or other formats
      # Thin delegate to Mathpix::Document
      class ConvertDocumentTool < BaseTool
        description 'Convert document (PDF, DOCX, PPTX) to Markdown, LaTeX, HTML, or other formats using Mathpix OCR'

        # Above this many characters, returning the converted content inline
        # would risk overflowing the LLM context window, so the result is
        # written to a file and only a path + preview is returned.
        DEFAULT_MAX_INLINE_CHARS = 50_000

        # Characters of the converted markdown to include as a preview when the
        # full content is written to a file instead of returned inline.
        PREVIEW_CHARS = 2_000

        input_schema(
          properties: {
            document_path: {
              type: 'string',
              description: 'Path to document file or URL (PDF, DOCX, or PPTX)'
            },
            formats: {
              type: 'array',
              items: { type: 'string' },
              description: 'Output formats: markdown, latex, html, docx (default: markdown)'
            },
            include_tables: {
              type: 'boolean',
              description: 'Include table extraction as HTML'
            },
            output_path: {
              type: 'string',
              description: 'If set, write the converted output to this file (markdown). Other ' \
                           'formats are written alongside with matching extensions. The response ' \
                           'then returns file paths + a short preview instead of the full content.'
            },
            max_inline_chars: {
              type: 'number',
              description: "Maximum characters to return inline before auto-saving to a file to " \
                           "avoid exceeding the model context (default: #{DEFAULT_MAX_INLINE_CHARS}). " \
                           'Ignored when output_path is set.'
            },
            max_wait: {
              type: 'number',
              description: 'Maximum wait time in seconds for conversion (default: 600)'
            },
            poll_interval: {
              type: 'number',
              description: 'Polling interval in seconds (default: 3.0)'
            }
          },
          required: ['document_path']
        )

        def self.call(document_path:, server_context:, formats: nil, include_tables: false,
                      output_path: nil, max_inline_chars: DEFAULT_MAX_INLINE_CHARS,
                      max_wait: 600, poll_interval: 3.0)
          safe_execute do
            client = mathpix_client(server_context)

            # Normalize path
            document_path = normalize_path(document_path) unless url?(document_path)

            # Extract formats or use defaults
            output_formats = extract_formats(formats, client)

            # Use Document class (new unified interface)
            doc = Mathpix::Document.new(client, document_path)
            doc.with_formats(*output_formats)
            doc.with_tables if include_tables

            # Start conversion and wait for completion
            conversion = doc.convert
            conversion.wait_until_complete(max_wait: max_wait, poll_interval: poll_interval)
            result = conversion.result

            contents = {
              markdown: result.markdown,
              latex: result.latex,
              html: result.html
            }.compact

            response_data = {
              success: true,
              document_path: document_path,
              formats: output_formats,
              conversion_id: conversion.conversion_id,
              metadata: {
                document_type: conversion.document_type,
                pages: result.page_count,
                processing_time: result.processing_time
              }
            }

            total_chars = contents.values.sum(&:length)

            if output_path
              # Explicit save requested.
              response_data[:saved_files] = save_contents(contents, File.expand_path(output_path))
              response_data[:preview] = preview_of(result.markdown)
            elsif total_chars <= max_inline_chars
              # Small enough to return inline.
              response_data[:results] = contents
            else
              # Too large to inline safely — auto-save to a temp file so the
              # model's context isn't blown out.
              default_path = File.join(Dir.tmpdir, "mathpix_#{sanitize(conversion.conversion_id)}.md")
              response_data[:saved_files] = save_contents(contents, default_path)
              response_data[:preview] = preview_of(result.markdown)
              response_data[:note] =
                "Converted output is #{total_chars} characters, which exceeds max_inline_chars " \
                "(#{max_inline_chars}); it was written to a file to avoid exceeding the model " \
                'context. Read the file at saved_files for the full content, pass output_path to ' \
                'choose the destination, or raise max_inline_chars to force inline output.'
            end

            json_response(response_data)
          end
        end

        # Write each available format to disk, deriving sibling paths for the
        # non-markdown formats from the markdown target's name.
        #
        # @param contents [Hash{Symbol=>String}] format => content
        # @param markdown_path [String] target path for the markdown output
        # @return [Hash{Symbol=>Hash}] format => { path:, bytes: }
        def self.save_contents(contents, markdown_path)
          ext_for = { markdown: nil, latex: 'tex', html: 'html' }
          saved = {}

          contents.each do |format, content|
            path =
              if format == :markdown
                markdown_path
              else
                sibling_path(markdown_path, ext_for[format] || format.to_s)
              end

            File.write(path, content)
            saved[format] = { path: path, bytes: content.bytesize }
          end

          saved
        end

        # Derive a sibling path with a different extension.
        def self.sibling_path(base, ext)
          dir = File.dirname(base)
          stem = File.basename(base, File.extname(base))
          File.join(dir, "#{stem}.#{ext}")
        end

        # First PREVIEW_CHARS characters of the content, if any.
        def self.preview_of(content)
          return nil unless content

          content.length > PREVIEW_CHARS ? "#{content[0, PREVIEW_CHARS]}…" : content
        end

        # Make a conversion id safe to use in a filename.
        def self.sanitize(value)
          value.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
        end
      end
    end
  end
end
