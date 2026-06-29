# frozen_string_literal: true

require_relative '../base_tool'

module Mathpix
  module MCP
    module Tools
      # Batch Convert Tool
      #
      # Converts multiple images in batch for efficiency
      # Thin delegate to Mathpix::Client#snap with batch processing
      class BatchConvertTool < BaseTool
        description 'Convert multiple images in batch using Mathpix OCR'

        input_schema(
          properties: {
            image_paths: {
              type: 'array',
              items: { type: 'string' },
              description: 'Array of image paths or URLs to process'
            },
            formats: {
              type: 'array',
              items: { type: 'string' },
              description: 'Output formats for all images: latex, text, mathml, asciimath (default: latex_styled, text)'
            },
            parallel: {
              type: 'boolean',
              description: 'Process images concurrently (default: false)'
            },
            max_parallel: {
              type: 'number',
              description: 'Maximum number of concurrent requests when parallel is true (default: 3)'
            }
          },
          required: ['image_paths']
        )

        def self.call(image_paths:, server_context:, formats: nil, parallel: false, max_parallel: 3)
          safe_execute do
            client = mathpix_client(server_context)

            # Extract formats or use defaults
            output_formats = extract_formats(formats, client)

            # Normalize paths
            normalized_paths = image_paths.map do |path|
              url?(path) ? path : normalize_path(path)
            end

            # Process images (concurrently when requested)
            results =
              if parallel
                process_batch_parallel(client, normalized_paths, output_formats, max_parallel.to_i)
              else
                process_batch_sequential(client, normalized_paths, output_formats)
              end

            # Format response
            response_data = {
              success: true,
              batch_size: image_paths.length,
              formats: output_formats,
              parallel: parallel,
              results: results,
              summary: {
                total: results.length,
                successful: results.count { |r| r[:success] },
                failed: results.count { |r| !r[:success] }
              }
            }

            json_response(response_data)
          end
        end

        # Convert a single image, returning a result/error hash (never raises).
        def self.convert_one(client, path, index, formats)
          result = client.snap(path, formats: formats)
          {
            index: index,
            image_path: path,
            success: true,
            latex: result.latex,
            text: result.text,
            confidence: result.confidence
          }
        rescue Mathpix::Error => e
          {
            index: index,
            image_path: path,
            success: false,
            error: e.message
          }
        end

        def self.process_batch_sequential(client, paths, formats)
          paths.map.with_index { |path, index| convert_one(client, path, index, formats) }
        end

        # Bounded thread pool: at most max_parallel concurrent HTTP requests.
        # Results are written back by original index so ordering is preserved.
        def self.process_batch_parallel(client, paths, formats, max_parallel)
          max_parallel = 1 if max_parallel < 1
          results = Array.new(paths.length)
          queue = Queue.new
          paths.each_with_index { |path, i| queue << [path, i] }

          worker_count = [max_parallel, paths.length].min
          workers = Array.new(worker_count) do
            Thread.new do
              loop do
                path, index = begin
                  queue.pop(true) # non-blocking; raises ThreadError when empty
                rescue ThreadError
                  break
                end
                results[index] = convert_one(client, path, index, formats)
              end
            end
          end

          workers.each(&:join)
          results
        end
      end
    end
  end
end
