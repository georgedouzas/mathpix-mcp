# frozen_string_literal: true

# MCP (Model Context Protocol) integration for Mathpix
#
# This module provides MCP server functionality using the official Ruby MCP SDK.
# All 9 tools are thin delegates to the core Mathpix::Client.
#
# Usage:
#   require 'mathpix/mcp'
#
#   Mathpix.configure do |config|
#     config.app_id = ENV['MATHPIX_APP_ID']
#     config.app_key = ENV['MATHPIX_APP_KEY']
#   end
#
#   Mathpix::MCP::Server.run

# Load MCP components (stdio server only)
require_relative 'mcp/server'
require_relative 'mcp/base_tool'

# Load all 9 tools
require_relative 'mcp/tools/convert_image_tool'
require_relative 'mcp/tools/convert_document_tool'
require_relative 'mcp/tools/convert_strokes_tool'
require_relative 'mcp/tools/batch_convert_tool'
require_relative 'mcp/tools/check_document_status_tool'
require_relative 'mcp/tools/search_results_tool'
require_relative 'mcp/tools/get_usage_tool'
require_relative 'mcp/tools/get_account_info_tool'
require_relative 'mcp/tools/list_formats_tool'
