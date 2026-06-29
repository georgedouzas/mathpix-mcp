# frozen_string_literal: true

module Mathpix
  # Base error class
  class Error < StandardError
    attr_reader :details

    def initialize(message, details: {})
      super(message)
      @details = details
    end
  end

  # Configuration error
  class ConfigurationError < Error; end

  # API error
  class APIError < Error
    attr_reader :status

    def initialize(message, status: nil, details: {})
      super(message, details: details)
      @status = status
    end
  end

  # Rate limit error
  class RateLimitError < APIError
    attr_reader :retry_after

    def initialize(message, retry_after: nil, **options)
      super(message, **options)
      @retry_after = retry_after
    end
  end

  # Server error (5xx)
  class ServerError < APIError; end

  # Network/timeout error
  class NetworkError < Error; end
  class TimeoutError < NetworkError; end

  # Low confidence error
  class LowConfidenceError < Error
    attr_reader :confidence, :suggestions

    def initialize(message, confidence: nil, suggestions: [])
      super(message)
      @confidence = confidence
      @suggestions = suggestions
    end
  end

  # Invalid request error (malformed input)
  class InvalidRequestError < Error; end

  # Invalid image error
  class InvalidImageError < Error
    attr_reader :recommended_format

    def initialize(message, recommended_format: nil)
      super(message)
      @recommended_format = recommended_format
    end
  end

  # Conversion error
  class ConversionError < Error
    attr_reader :conversion_id, :conversion_status

    def initialize(message, conversion_id: nil, conversion_status: nil)
      super(message)
      @conversion_id = conversion_id
      @conversion_status = conversion_status
    end
  end
end
