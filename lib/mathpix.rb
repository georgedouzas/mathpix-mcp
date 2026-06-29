# frozen_string_literal: true

require 'net/http'
require 'openssl'
require 'json'
require 'base64'

require_relative 'mathpix/version'
require_relative 'mathpix/errors'
require_relative 'mathpix/configuration'
require_relative 'mathpix/result'
require_relative 'mathpix/conversion'
require_relative 'mathpix/chemistry'
require_relative 'mathpix/client'
require_relative 'mathpix/document'

# Mathpix OCR engine for the MCP server.
#
# The classes under Mathpix:: are the engine the MCP tools delegate to
# (see lib/mathpix/mcp). Only configuration and the shared client instance are
# exposed at the top level — there is no general-purpose client API.
module Mathpix
  class << self
    # Configure the Mathpix client.
    #
    # @yield [Configuration] config object
    # @example
    #   Mathpix.configure do |config|
    #     config.app_id = ENV['MATHPIX_APP_ID']
    #     config.app_key = ENV['MATHPIX_APP_KEY']
    #   end
    def configure
      yield configuration
    end

    # Current configuration.
    # @return [Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # Shared client instance used by the MCP tools.
    # @return [Client]
    def client
      @client ||= Client.new(configuration)
    end

    # Reset configuration and client (mainly for tests).
    def reset!
      @configuration = Configuration.new
      @client = nil
    end
  end
end
