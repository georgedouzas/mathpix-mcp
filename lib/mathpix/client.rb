# frozen_string_literal: true

module Mathpix
  # Core HTTP client for Mathpix API
  class Client
    attr_reader :config

    def initialize(config = Mathpix.configuration)
      @config = config
      config.validate!
    end

    # Snap image to equation (core method)
    #
    # Supports both local file paths and remote URLs
    #
    # @param image_path_or_url [String, Hash] path to image, URL, or hash with :path/:url key
    # @param options [Hash] request options
    # @return [Result]
    # @example Local file
    #   client.snap('equation.png')
    # @example Remote URL
    #   client.snap('https://example.com/equation.png')
    #   client.snap(url: 'https://example.com/equation.png')
    # @example With options
    #   client.snap('equation.png', formats: [:latex, :mathml])
    def snap(image_path_or_url, **options)
      src, source_ref = prepare_image_source(image_path_or_url, options)

      response = post('/text', {
                        src: src,
                        formats: (options[:formats] || config.default_formats).map(&:to_s),
                        include_line_data: options[:include_line_data] || false,
                        **build_request_options(options)
                      })

      Result.new(response, source_ref)
    end

    # Get recent captures
    #
    # @param limit [Integer] number of results
    # @return [Array<Result>]
    def recent(limit: 10)
      response = get('/ocr-results', params: { limit: limit })
      response['data'].map { |data| Result.new(data) }
    end

    # Search captures
    #
    # @yield [SearchQuery] query builder (future)
    # @return [Array<Result>]
    def search(*)
      # Server-side search is not implemented by Mathpix for app tokens. Use
      # #recent and filter client-side (see SearchResultsTool). Raising is
      # honest — the previous stub silently returned [].
      raise NotImplementedError,
            'Mathpix::Client#search is not implemented; use #recent and filter results client-side'
    end

    # Convert Mathpix Markdown to multiple formats
    #
    # Async operation - returns Conversion object to poll for completion
    #
    # @param mmd [String] Mathpix Markdown content
    # @param formats [Array<Symbol, String>] output formats
    # @param options [Hash] conversion options
    # @return [Conversion] conversion object (async)
    # @example
    #   conversion = client.convert_mmd(
    #     mmd: "\\frac{1}{2} + \\sqrt{3}",
    #     formats: [:pdf, :docx, :html]
    #   )
    #   conversion.wait_until_complete
    #   conversion.to_pdf_file('output.pdf')
    def convert_mmd(mmd:, formats:, **options)
      # Build formats hash for API
      formats_hash = Array(formats).each_with_object({}) do |format, hash|
        hash[format.to_s] = true
      end

      response = post('/converter', {
                        mmd: mmd,
                        formats: formats_hash,
                        conversion_options: options[:conversion_options] || {}
                      })

      conversion_id = response['conversion_id']
      Conversion.new(self, conversion_id: conversion_id, mmd: mmd, formats: formats)
    end

    # Get conversion status
    #
    # @param conversion_id [String] conversion ID
    # @return [Hash] status data
    def get_conversion_status(conversion_id)
      get("/converter/#{conversion_id}")
    end

    # Download file from URL
    #
    # @param url [String] download URL
    # @return [String] file content as bytes
    def download(url)
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request['app_id'] = config.app_id
      request['app_key'] = config.app_key
      request['User-Agent'] = config.user_agent

      response = make_request(uri, request)

      case response
      when Net::HTTPSuccess
        response.body
      else
        raise APIError.new(
          "Download failed: #{response.code}",
          status: response.code.to_i
        )
      end
    end

    # Convert document (PDF, DOCX, PPTX) asynchronously
    #
    #
    # @param document_path [String] path to document file
    # @param document_type [Symbol] :pdf, :docx, :pptx
    # @param options [Hash] conversion options
    # @return [String] conversion_id for polling
    # @example
    #   conversion_id = client.convert_document(
    #     document_path: 'paper.pdf',
    #     document_type: :pdf,
    #     formats: [:markdown, :latex]
    #   )
    def convert_document(document_path:, document_type:, **options)
      conversion_formats = build_conversion_formats(options)
      request_options = build_document_options(options)

      # The /v3/pdf endpoint takes a remote PDF via the `url` field, or a local
      # file via multipart upload — NOT the base64 `src` field used by the image
      # (/v3/text) endpoint. Sending `src` made Mathpix reply "Missing URL in
      # request body", which previously surfaced as a useless generic
      # "Client error".
      response =
        if url?(document_path)
          post('/pdf', { url: document_path, conversion_formats: conversion_formats }.merge(request_options))
        else
          post_multipart('/pdf', document_path, { conversion_formats: conversion_formats }.merge(request_options))
        end

      pdf_id = response['pdf_id']
      return pdf_id if pdf_id

      # 200 OK with an error body (missing/invalid fields, etc.)
      raise APIError.new(
        "Document submission failed: #{extract_error_message(response) || 'no pdf_id returned by Mathpix'}",
        status: 200,
        details: response.is_a?(Hash) ? response : {}
      )
    end

    # Get document conversion status
    #
    # @param conversion_id [String] document conversion ID
    # @return [Hash] status data
    def get_document_status(conversion_id)
      get("/pdf/#{conversion_id}")
    end

    # Fetch a rendered document output (e.g. 'mmd', 'md', 'html', 'tex')
    #
    # The /v3/pdf/{id}.{ext} endpoints return the raw converted content; the
    # status endpoint (get_document_status) never contains it.
    #
    # @param conversion_id [String] document conversion ID
    # @param format [String] output extension (mmd, md, html, tex, ...)
    # @return [String] raw output content
    def get_document_output(conversion_id, format)
      uri = URI("#{config.endpoint}/pdf/#{conversion_id}.#{format}")
      request = Net::HTTP::Get.new(uri)
      request['app_id'] = config.app_id
      request['app_key'] = config.app_key
      request['User-Agent'] = config.user_agent

      response = make_request(uri, request)
      # Net::HTTP returns ASCII-8BIT bodies; Mathpix text outputs are UTF-8.
      return response.body.to_s.dup.force_encoding(Encoding::UTF_8) if response.is_a?(Net::HTTPSuccess)

      error_data = begin
        JSON.parse(response.body)
      rescue StandardError
        {}
      end
      raise APIError.new(
        "Failed to fetch '#{format}' output: #{extract_error_message(error_data) || "HTTP #{response.code}"}",
        status: response.code.to_i,
        details: error_data.is_a?(Hash) ? error_data : {}
      )
    end

    private

    # Build conversion formats hash
    #
    # @param options [Hash] user options
    # @return [Hash] formats configuration
    # Map requested output formats to valid Mathpix /v3/pdf `conversion_formats`
    # keys. Unknown keys (text, latex_styled, ...) are dropped so we never send
    # an invalid format that the API rejects.
    CONVERSION_FORMAT_MAP = {
      'docx' => 'docx', 'pptx' => 'pptx', 'pdf' => 'pdf',
      'tex' => 'tex.zip', 'tex.zip' => 'tex.zip', 'latex' => 'tex.zip',
      'html' => 'html', 'md' => 'md', 'mmd' => 'md', 'markdown' => 'md'
    }.freeze

    def build_conversion_formats(options)
      formats = {}
      Array(options[:formats]).each do |fmt|
        key = CONVERSION_FORMAT_MAP[fmt.to_s.downcase]
        formats[key] = true if key
      end
      formats['md'] = true # always enable Markdown retrieval
      formats
    end

    # Build document-specific options
    #
    # @param options [Hash] user options
    # @return [Hash] document options
    def build_document_options(options)
      {}.tap do |opts|
        opts[:include_table_html] = true if options[:include_table_html]
        opts[:include_diagram_svg] = true if options[:include_diagram_svg]
        opts[:include_line_data] = true if options[:include_line_data]
        opts[:include_word_data] = true if options[:include_word_data]
        opts[:quality] = options[:quality] if options[:quality]
        opts[:page_ranges] = options[:page_ranges] if options[:page_ranges]
      end
    end

    # Prepare image source (URL or local file)
    #
    # Automatically upgrades HTTP to HTTPS
    #
    # @param input [String, Hash] path, URL, or hash with :path/:url key
    # @param options [Hash] additional options
    # @return [Array<String, String>] src value and source reference
    # @raise [InvalidRequestError] if input looks like malformed URL
    def prepare_image_source(input, _options = {})
      # Handle hash input: { url: '...' } or { path: '...' }
      if input.is_a?(Hash)
        if input[:url] || input['url']
          url = input[:url] || input['url']
          url = config.upgrade_to_https(url) # Auto-upgrade HTTP→HTTPS
          validate_url!(url) # Raise InvalidRequestError if malformed
          return [url, url]
        elsif input[:path] || input['path']
          path = input[:path] || input['path']
          return [encode_image(path), path]
        end
      end

      # Auto-upgrade HTTP to HTTPS BEFORE validation
      # This ensures HTTP URLs pass validation after upgrade
      upgraded_input = config.upgrade_to_https(input)

      # Detect if input is URL or local path
      if url?(upgraded_input)
        [upgraded_input, upgraded_input] # Use URL directly as src
      elsif looks_like_url?(input)
        # String contains URL-like patterns but isn't valid
        raise InvalidRequestError, "Invalid URL format: #{input}"
      else
        # Try to encode as local file
        begin
          [encode_image(input), input] # Encode local file (use original path)
        rescue SecurityError, Errno::ENOENT
          # If file encoding fails and input doesn't look like a file path,
          # it's likely a malformed URL
          raise InvalidRequestError, "Invalid URL format: #{input}" unless looks_like_file_path?(input)

          raise # Re-raise original error for actual file path issues
        end
      end
    end

    # Check if string is a URL (using secure configuration validation)
    #
    # @param str [String] string to check
    # @return [Boolean]
    def url?(str)
      return false unless str.is_a?(String)

      config.valid_url?(str)
    end

    # Check if string looks like a URL but may not be valid
    #
    # Detects patterns that suggest URL intent: protocol prefixes, www prefix
    # Used to provide better error messages for malformed URLs
    #
    # @param str [String] string to check
    # @return [Boolean]
    def looks_like_url?(str)
      return false unless str.is_a?(String)

      # URL-like patterns: contains protocol or www prefix
      str.match?(%r{^(https?://|www\.)|://})
    end

    # Validate URL and raise InvalidRequestError if malformed
    #
    # @param url [String] URL to validate
    # @raise [InvalidRequestError] if URL is not valid
    def validate_url!(url)
      return if config.valid_url?(url)

      raise InvalidRequestError, "Invalid URL format: #{url}"
    end

    # Check if string looks like a file path
    #
    # Detects patterns that suggest file path intent: directory separators,
    # file extensions, relative/absolute path markers
    #
    # @param str [String] string to check
    # @return [Boolean]
    def looks_like_file_path?(str)
      return false unless str.is_a?(String)

      # File path patterns: contains slashes, starts with ~, has file extension, or starts with .
      str.match?(%r{^[~/.]|/|\\|\.(?:png|jpe?g|gif|webp|pdf|docx|pptx)$}i)
    end

    # Encode image to base64 data URI (with path sanitization)
    #
    # @param path [String] path to image file
    # @return [String] data URI
    # @raise [SecurityError] if path is invalid or dangerous
    def encode_image(path)
      # Sanitize path to prevent directory traversal
      sanitized_path = config.sanitize_path(path)
      raise SecurityError, "Invalid or dangerous file path: #{path}" if sanitized_path.nil?

      content = File.binread(sanitized_path)
      mime_type = detect_mime_type(sanitized_path)
      "data:#{mime_type};base64,#{Base64.strict_encode64(content)}"
    end

    # Detect MIME type from file extension
    #
    # @param path [String] file path
    # @return [String] MIME type
    def detect_mime_type(path)
      case File.extname(path).downcase
      when '.png' then 'image/png'
      when '.jpg', '.jpeg' then 'image/jpeg'
      when '.gif' then 'image/gif'
      when '.webp' then 'image/webp'
      when '.pdf' then 'application/pdf'
      when '.docx' then 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      when '.pptx' then 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
      else 'application/octet-stream'
      end
    end

    # Build request options from user input + defaults
    #
    # @param options [Hash] user options
    # @return [Hash] complete request options
    def build_request_options(options)
      {}.tap do |opts|
        # Data options
        if options[:include_latex]
          opts[:data_options] ||= {}
          opts[:data_options][:include_latex] = true
        end

        # Metadata
        opts[:metadata] = options[:metadata] if options[:metadata]
        opts[:tags] = Array(options[:tags]) if options[:tags]

        # Recognition options
        opts[:rm_spaces] = options[:rm_spaces] if options.key?(:rm_spaces)
        opts[:idiomatic_eqn_arrays] = options[:idiomatic_eqn_arrays] if options.key?(:idiomatic_eqn_arrays)

        # Confidence threshold
        opts[:confidence_threshold] = options[:confidence_threshold] if options[:confidence_threshold]

        # Chemistry
        opts[:include_smiles] = true if options[:chemistry] || options[:include_smiles]

        # Alphabets
        opts[:alphabets_allowed] = options[:alphabets] if options[:alphabets]
      end
    end

    # Make POST request
    #
    # @param path [String] API endpoint path
    # @param body [Hash] request body
    # @return [Hash] parsed response
    def post(path, body)
      uri = URI("#{config.endpoint}#{path}")
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['app_id'] = config.app_id
      request['app_key'] = config.app_key
      request['User-Agent'] = config.user_agent
      request.body = JSON.generate(body)

      response = make_request(uri, request)
      handle_response(response)
    end

    # Make multipart POST request (local file upload)
    #
    # @param path [String] API endpoint path
    # @param file_path [String] local file to upload
    # @param fields [Hash] extra form fields (sent as options_json)
    # @return [Hash] parsed response
    def post_multipart(path, file_path, fields)
      uri = URI("#{config.endpoint}#{path}")
      request = Net::HTTP::Post.new(uri)
      request['app_id'] = config.app_id
      request['app_key'] = config.app_key
      request['User-Agent'] = config.user_agent

      file = File.open(file_path, 'rb')
      begin
        request.set_form(
          [['file', file], ['options_json', JSON.generate(fields)]],
          'multipart/form-data'
        )
        response = make_request(uri, request)
      ensure
        file.close
      end

      handle_response(response)
    end

    # Make GET request
    #
    # @param path [String] API endpoint path
    # @param params [Hash] query parameters
    # @return [Hash] parsed response
    def get(path, params: {})
      uri = URI("#{config.endpoint}#{path}")
      uri.query = URI.encode_www_form(params) unless params.empty?

      request = Net::HTTP::Get.new(uri)
      request['app_id'] = config.app_id
      request['app_key'] = config.app_key
      request['User-Agent'] = config.user_agent

      response = make_request(uri, request)
      handle_response(response)
    end

    # Execute HTTP request with error handling
    #
    # @param uri [URI] request URI
    # @param request [Net::HTTPRequest] HTTP request object
    # @return [Net::HTTPResponse]
    def make_request(uri, request)
      Net::HTTP.start(uri.hostname, uri.port,
                      use_ssl: uri.scheme == 'https',
                      read_timeout: config.timeout) do |http|
        http.request(request)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise TimeoutError, "Request timed out after #{config.timeout}s: #{e.message}"
    rescue SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError,
           Net::HTTPBadResponse, Net::ProtocolError => e
      # Genuine network/transport failures get relabeled for callers. Other
      # StandardErrors (e.g. a programming bug in this method) now propagate
      # untouched instead of being masked as a misleading "Network error".
      raise NetworkError, "Network error: #{e.message}"
    end

    # Handle API response
    #
    # @param response [Net::HTTPResponse]
    # @return [Hash] parsed response body
    # @raise [APIError] on error response
    def handle_response(response)
      case response
      when Net::HTTPSuccess
        data = parse_body(response)
        # Mathpix occasionally returns HTTP 200 with an error payload
        # (e.g. "Missing URL in request body"). Surface it rather than
        # silently treating the request as successful.
        if data.is_a?(Hash) && (data['error'] || data['error_info'])
          raise APIError.new(
            extract_error_message(data) || 'Mathpix returned an error',
            status: response.code.to_i,
            details: data
          )
        end
        data
      when Net::HTTPTooManyRequests
        raise RateLimitError.new(
          'Rate limit exceeded',
          retry_after: response['Retry-After']&.to_i
        )
      when Net::HTTPClientError
        error_data = parse_body(response)
        raise APIError.new(
          extract_error_message(error_data) || "Client error (HTTP #{response.code})",
          status: response.code.to_i,
          details: error_data.is_a?(Hash) ? error_data : {}
        )
      when Net::HTTPServerError
        error_data = parse_body(response)
        raise ServerError.new(
          extract_error_message(error_data) || "Server error (HTTP #{response.code})",
          status: response.code.to_i,
          details: error_data.is_a?(Hash) ? error_data : {}
        )
      else
        raise APIError.new(
          "Unexpected response: HTTP #{response.code}",
          status: response.code.to_i
        )
      end
    end

    # Parse a response body as JSON, tolerating empty/non-JSON bodies
    #
    # @param response [Net::HTTPResponse]
    # @return [Hash, Array] parsed body, or { 'error' => raw } for non-JSON
    def parse_body(response)
      body = response.body.to_s
      return {} if body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      # Non-JSON body (often an HTML error page) — keep a concise summary
      # instead of dumping the whole page as the error message.
      { 'error' => "HTTP #{response.code} #{response.message}".strip }
    end

    # Pull the most descriptive message out of a Mathpix error payload.
    # Mathpix nests the human-readable reason under error_info.message.
    #
    # @param data [Hash] parsed error body
    # @return [String, nil]
    def extract_error_message(data)
      return nil unless data.is_a?(Hash)

      data.dig('error_info', 'message') ||
        data.dig('error_info', 'id') ||
        data['error'] ||
        data['message']
    end

    # `get`/`post` are part of the public surface used by the MCP tools
    # (e.g. GetAccountInfoTool calls client.get('/account')). They were
    # previously private, raising "private method 'get' called".
    public :get, :post
  end
end
