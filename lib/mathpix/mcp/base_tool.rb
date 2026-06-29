# frozen_string_literal: true

require 'tmpdir'

module Mathpix
  module MCP
    module Tools
      # Base class for all Mathpix MCP tools
      #
      # Uses official Ruby MCP SDK (MCP::Tool)
      # Provides common utilities for Mathpix-specific tools
      #
      #
      # @example Tool implementation
      #   class ExampleTool < BaseTool
      #     description "Example tool"
      #     input_schema(
      #       properties: { message: { type: "string" } },
      #       required: ["message"]
      #     )
      #
      #     def self.call(message:, server_context:)
      #       client = server_context[:mathpix_client]
      #       # Use client to make API calls
      #       text_response("Result: #{message}")
      #     end
      #   end
      class BaseTool < ::MCP::Tool
        class << self
          protected

          # Get Mathpix client from server context
          #
          # @param server_context [Hash] MCP server context
          # @return [Mathpix::Client] Mathpix API client
          def mathpix_client(server_context)
            server_context[:mathpix_client] || raise(ArgumentError, 'mathpix_client not in server_context')
          end

          # Create text response (official MCP format)
          #
          # @param text [String] response text
          # @return [::MCP::Tool::Response]
          def text_response(text)
            ::MCP::Tool::Response.new([{
                                        type: 'text',
                                        text: text
                                      }])
          end

          # Create JSON response with text wrapper
          #
          # @param data [Hash] JSON data
          # @return [::MCP::Tool::Response]
          def json_response(data)
            text_response(JSON.pretty_generate(data))
          end

          # Create error response
          #
          # @param error [StandardError, String] error object or message
          # @return [::MCP::Tool::Response]
          def error_response(error)
            message = error.is_a?(StandardError) ? error.message : error.to_s
            details = error.is_a?(Mathpix::Error) ? error.details : {}

            error_data = {
              error: true,
              message: message,
              type: error.is_a?(StandardError) ? error.class.name : 'Error'
            }
            error_data[:status] = error.status if error.is_a?(Mathpix::APIError) && error.status
            error_data[:details] = details unless details.nil? || details.empty?

            json_response(error_data)
          end

          # Extract formats from arguments
          #
          # @param formats [Array, nil] format array
          # @param client [Mathpix::Client] client for defaults
          # @return [Array<Symbol>] format symbols
          def extract_formats(formats, client)
            return client.config.default_formats if formats.nil? || formats.empty?

            Array(formats).map(&:to_sym)
          end

          # Normalize path (expand ~, resolve relative paths)
          #
          # @param path [String] file path
          # @return [String] normalized path
          def normalize_path(path)
            File.expand_path(path)
          rescue StandardError
            path
          end

          # Check if path is a URL
          #
          # @param path [String] path or URL
          # @return [Boolean]
          def url?(path)
            path.to_s.start_with?('http://', 'https://')
          end

          # Characters of inline preview returned alongside a saved artifact.
          PREVIEW_CHARS = 2_000

          # Map an OCR format name to a sensible file extension.
          ARTIFACT_EXT = {
            'markdown' => 'md', 'md' => 'md', 'mmd' => 'mmd',
            'latex' => 'tex', 'latex_styled' => 'tex', 'latex_simplified' => 'tex',
            'text' => 'txt', 'text_display' => 'txt', 'asciimath' => 'txt',
            'mathml' => 'mml', 'html' => 'html', 'data' => 'json',
            'line_data' => 'json', 'word_data' => 'json'
          }.freeze

          # Directory where OCR artifacts are written when no explicit
          # output_path is given. Configurable via MATHPIX_OUTPUT_DIR; defaults
          # to the system temp dir.
          #
          # @return [String]
          def artifact_dir
            dir = ENV.fetch('MATHPIX_OUTPUT_DIR', nil)
            dir && !dir.empty? ? File.expand_path(dir) : Dir.tmpdir
          end

          # Make a value safe to embed in a filename.
          #
          # @param value [#to_s]
          # @return [String]
          def sanitize(value)
            value.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
          end

          # Short inline preview of a piece of content.
          #
          # @param content [String, nil]
          # @param limit [Integer]
          # @return [String, nil]
          def preview_of(content, limit = PREVIEW_CHARS)
            return nil if content.nil?

            str = content.to_s
            str.length > limit ? "#{str[0, limit]}…" : str
          end

          # Derive a sibling path with a different extension.
          #
          # @param base [String] base file path
          # @param ext [String] extension without the dot
          # @return [String]
          def sibling_path(base, ext)
            dir = File.dirname(base)
            stem = File.basename(base, File.extname(base))
            File.join(dir, "#{stem}.#{ext}")
          end

          # Write OCR artifacts to disk so their (potentially large) content
          # never enters the model context. The first format is written to
          # base_path (honoring any extension the caller chose); the rest are
          # written to siblings whose extension is derived from the format name.
          #
          # @param contents [Hash{String,Symbol=>String}] format => content
          # @param base_path [String] primary output path
          # @return [Hash{String=>Hash}] format => { path:, bytes: }
          def write_artifacts(contents, base_path)
            base_path = File.expand_path(base_path)
            ensure_dir(File.dirname(base_path))
            saved = {}
            first = true

            contents.each do |format, content|
              next if content.nil? || content.to_s.empty?

              name = format.to_s
              path =
                if first
                  first = false
                  base_path
                else
                  sibling_path(base_path, ARTIFACT_EXT[name] || 'txt')
                end

              str = content.is_a?(String) ? content : JSON.pretty_generate(content)
              File.write(path, str)
              saved[name] = { path: path, bytes: str.bytesize }
            end

            saved
          end

          # Build a default artifact base path inside artifact_dir.
          #
          # @param stem [String] human-meaningful filename stem
          # @param ext [String] extension without the dot
          # @return [String]
          def default_artifact_path(stem, ext)
            File.join(artifact_dir, "mathpix_#{sanitize(stem)}.#{ext}")
          end

          # Ensure a directory exists (lazily requiring fileutils so tools that
          # never write files don't pay for it).
          def ensure_dir(dir)
            require 'fileutils'
            FileUtils.mkdir_p(dir)
          end

          # Safe execute with error handling
          #
          # @yield Block to execute
          # @return [::MCP::Tool::Response]
          def safe_execute
            yield
          rescue Mathpix::Error => e
            error_response(e)
          rescue StandardError => e
            error_response(e)
          end
        end
      end
    end
  end
end
