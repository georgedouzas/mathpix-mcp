# frozen_string_literal: true

module Mathpix
  # Configuration class with security defaults and validation
  # Seed: 1069 - Deterministic configuration values
  class Configuration
    # Security constants
    HTTPS_ONLY = true
    MAX_FILE_SIZE_MB = 10
    MAX_PATH_LENGTH = 1024
    ALLOWED_SCHEMES = %w[https].freeze

    # Resource limits
    MIN_LIMIT = 1
    MAX_LIMIT = 100
    DEFAULT_LIMIT = 10

    # Confidence thresholds (balanced ternary seed 1069)
    CONFIDENCE_HIGH = 0.9
    CONFIDENCE_MEDIUM = 0.7
    CONFIDENCE_LOW = 0.5

    # Rate limiting (requests per minute)
    RATE_LIMIT_DEFAULT = 60
    RATE_LIMIT_BURST = 10

    attr_accessor :app_id, :app_key, :api_url, :timeout, :default_formats,
                  :user_agent, :enforce_https, :max_file_size_mb, :logger, :seed

    attr_reader :rate_limit, :confidence_thresholds

    # Alias endpoint for api_url
    alias endpoint api_url
    alias endpoint= api_url=

    def initialize
      @app_id = ENV.fetch('MATHPIX_APP_ID', nil)
      @app_key = ENV.fetch('MATHPIX_APP_KEY', nil)
      @api_url = ENV.fetch('MATHPIX_API_URL', 'https://api.mathpix.com/v3')
      @timeout = ENV.fetch('MATHPIX_TIMEOUT', '30').to_i
      @default_formats = [:latex_styled]
      @user_agent = "mathpix-ruby/#{Mathpix::VERSION}"

      # Security settings
      @enforce_https = HTTPS_ONLY
      @max_file_size_mb = MAX_FILE_SIZE_MB
      @max_path_length = MAX_PATH_LENGTH

      # Resource limits
      @min_limit = MIN_LIMIT
      @max_limit = MAX_LIMIT
      @default_limit = DEFAULT_LIMIT

      # Confidence thresholds
      @confidence_thresholds = {
        high: CONFIDENCE_HIGH,
        medium: CONFIDENCE_MEDIUM,
        low: CONFIDENCE_LOW
      }

      # Rate limiting
      @rate_limit = RATE_LIMIT_DEFAULT

      # Structured logging
      @logger = nil # Can be set to Logger instance
    end

    def validate!
      raise ConfigurationError, 'app_id is required' if app_id.nil? || app_id.empty?
      raise ConfigurationError, 'app_key is required' if app_key.nil? || app_key.empty?

      # Validate API URL uses HTTPS
      raise ConfigurationError, 'API URL must use HTTPS' if enforce_https && !api_url.start_with?('https://')

      # Validate timeout
      raise ConfigurationError, 'Timeout must be between 1 and 300 seconds' if timeout <= 0 || timeout > 300

      true
    end

    # Sanitize limit to be within bounds
    #
    # @param limit [Integer] requested limit
    # @return [Integer] clamped limit
    def sanitize_limit(limit)
      [[limit.to_i, @min_limit].max, @max_limit].min
    end

    # Check if URL is allowed (HTTPS only)
    #
    # @param url [String] URL to validate
    # @return [Boolean]
    def valid_url?(url)
      return false unless url.is_a?(String)
      return false if url.length > @max_path_length

      uri = URI.parse(url)

      # Must be HTTP(S) scheme
      return false unless %w[http https].include?(uri.scheme)

      # Enforce HTTPS if enabled
      return false if enforce_https && uri.scheme != 'https'

      # Must have a host
      return false if uri.host.nil? || uri.host.empty?

      # Block localhost and private IPs
      return false if uri.host.match?(/^(localhost|127\.|0\.0\.0\.0|::1)/)
      return false if uri.host.match?(/^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)/)

      true
    rescue URI::InvalidURIError
      false
    end

    # Auto-upgrade HTTP to HTTPS for remote URLs
    #
    # This provides the same behavior for seamless URL support
    #
    # @param url [String] URL that may be HTTP or HTTPS
    # @return [String] URL with https:// scheme
    # @example
    #   upgrade_to_https('http://example.com/img.png')
    #   # => 'https://example.com/img.png'
    def upgrade_to_https(url)
      return url unless url.is_a?(String)
      return url unless url.start_with?('http://')

      url.sub(%r{^http://}, 'https://')
    end

    # Sanitize file path to prevent directory traversal
    #
    # @param path [String] file path
    # @return [String, nil] sanitized path or nil if invalid
    def sanitize_path(path)
      return nil unless path.is_a?(String)
      return nil if path.length > @max_path_length

      # Remove null bytes
      path = path.tr("\0", '')

      # Normalize path
      normalized = File.expand_path(path)

      # Check for directory traversal attempts
      return nil if normalized.include?('../')
      return nil if normalized.match?(%r{\.\.[/\\]})

      # Check file exists (for local paths)
      return nil unless File.exist?(normalized)

      # Check file size
      size_mb = File.size(normalized).to_f / (1024 * 1024)
      return nil if size_mb > @max_file_size_mb

      normalized
    rescue StandardError
      nil
    end

    # Log structured message
    #
    # @param level [Symbol] log level (:debug, :info, :warn, :error)
    # @param message [String] log message
    # @param data [Hash] structured data
    def log(level, message, data = {})
      return unless @logger

      structured_message = {
        timestamp: Time.now.utc.iso8601,
        level: level,
        message: message,
        seed: 1069,
        **data
      }.to_json

      @logger.send(level, structured_message)
    end
  end
end
