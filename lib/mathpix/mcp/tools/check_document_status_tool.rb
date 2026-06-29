# frozen_string_literal: true

require_relative '../base_tool'

module Mathpix
  module MCP
    module Tools
      # Check Document Status Tool
      #
      # Polls document conversion status for async operations
      # Thin delegate to Mathpix::Client#get_document_status
      class CheckDocumentStatusTool < BaseTool
        description 'Check the status of a document conversion (PDF, DOCX, PPTX)'

        input_schema(
          properties: {
            conversion_id: {
              type: 'string',
              description: 'Document conversion ID returned from convert_document'
            }
          },
          required: ['conversion_id']
        )

        def self.call(conversion_id:, server_context:)
          safe_execute do
            client = mathpix_client(server_context)

            # Delegate to core gem
            status_data = client.get_document_status(conversion_id)

            # Format response
            response_data = {
              success: true,
              conversion_id: conversion_id,
              status: status_data['status'],
              progress: status_data['percent_done'],
              metadata: {}
            }

            # Add completion data if available
            if status_data['status'] == 'completed'
              response_data[:metadata][:pages] = status_data['num_pages']
              response_data[:metadata][:pages_completed] = status_data['num_pages_completed']
              # The /v3/pdf status payload does NOT contain markdown_url/latex_url/
              # html_url (those were always nil). The converted content lives at
              # the /pdf/{id}.{ext} endpoints — report those, and how to fetch.
              endpoint = client.config.endpoint
              response_data[:results] = {
                markdown_endpoint: "#{endpoint}/pdf/#{conversion_id}.mmd",
                html_endpoint: "#{endpoint}/pdf/#{conversion_id}.html",
                tex_endpoint: "#{endpoint}/pdf/#{conversion_id}.tex",
                note: 'Fetch these with app_id/app_key headers, or call ' \
                      'convert_document_tool to get the content directly.'
              }
            end

            # Add error info if failed
            if %w[error failed].include?(status_data['status'])
              response_data[:error] = status_data['error']
              response_data[:error_info] = status_data['error_info']
            end

            json_response(response_data)
          end
        end
      end
    end
  end
end
