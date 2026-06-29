# frozen_string_literal: true

module Mathpix
  # Mathpix Markdown (MMD) conversion to multiple formats
  # Handles async conversion via POST /v3/converter
  class Conversion
    attr_reader :conversion_id, :mmd, :formats, :client

    # Conversion status states
    STATUS_QUEUED = 'queued'
    STATUS_PROCESSING = 'processing'
    STATUS_COMPLETED = 'completed'
    STATUS_ERROR = 'error'

    # Supported output formats (verified from Mathpix API docs)
    SUPPORTED_FORMATS = %w[
      md docx tex.zip html pdf latex_pdf pptx
      mmd.zip md.zip html.zip
    ].freeze

    def initialize(client, conversion_id: nil, mmd: nil, formats: nil)
      @client = client
      @conversion_id = conversion_id
      @mmd = mmd
      @formats = formats
      @status_data = nil
    end

    # Check conversion status
    #
    # @return [String] status (queued, processing, completed, error)
    def status
      refresh_status unless @status_data
      @status_data['status']
    end

    # Check if conversion is complete
    #
    # @return [Boolean]
    def completed?
      status == STATUS_COMPLETED
    end

    # Check if conversion is still processing
    #
    # @return [Boolean]
    def processing?
      [STATUS_QUEUED, STATUS_PROCESSING].include?(status)
    end

    # Check if conversion failed
    #
    # @return [Boolean]
    def error?
      status == STATUS_ERROR
    end

    # Get error message if conversion failed
    #
    # @return [String, nil]
    def error_message
      @status_data&.dig('error')
    end

    # Wait until conversion is complete
    #
    # @param max_wait [Integer] maximum seconds to wait (default: 300 = 5 minutes)
    # @param poll_interval [Float] seconds between status checks (default: 2.0)
    # @return [self]
    # @raise [TimeoutError] if max_wait exceeded
    # @raise [ConversionError] if conversion fails
    def wait_until_complete(max_wait: 300, poll_interval: 2.0)
      start_time = Time.now

      loop do
        refresh_status

        return self if completed?

        raise ConversionError, "Conversion failed: #{error_message}" if error?

        elapsed = Time.now - start_time
        raise TimeoutError, "Conversion timed out after #{max_wait}s (status: #{status})" if elapsed > max_wait

        # Anything that isn't completed/error is non-terminal — always sleep
        # before polling again. (Previously this only slept for the known
        # queued/processing states, busy-looping on any other status.)
        sleep poll_interval
      end
    end

    # Poll until complete (alias for wait_until_complete)
    #
    # @param max_wait [Integer] maximum seconds to wait
    # @param poll_interval [Float] seconds between checks
    # @return [self]
    def poll_until_ready(max_wait: 300, poll_interval: 2.0)
      wait_until_complete(max_wait: max_wait, poll_interval: poll_interval)
    end

    # Get converted output for a specific format
    #
    # @param format [String, Symbol] output format (e.g., 'pdf', :docx)
    # @return [String] file content as bytes
    # @raise [Error] if conversion not complete
    def output(format)
      raise Error, "Conversion not complete (status: #{status})" unless completed?

      format_str = format.to_s
      url = output_url(format_str)

      client.download(url)
    end

    # Save output to file
    #
    # @param format [String, Symbol] output format
    # @param path [String] destination file path
    # @return [String] path to saved file
    def save_output(format, path)
      content = output(format)
      File.binwrite(path, content)
      path
    end

    # --- Format-specific convenience methods ---

    # Get PDF output as bytes
    # @return [String] binary PDF content
    def to_pdf_bytes
      output(:pdf)
    end

    # Save PDF to file
    # @param path [String] destination path
    # @return [String] path
    def to_pdf_file(path)
      save_output(:pdf, path)
    end

    # Get DOCX output as bytes
    # @return [String] binary DOCX content
    def to_docx_bytes
      output(:docx)
    end

    # Save DOCX to file
    # @param path [String] destination path
    # @return [String] path
    def to_docx_file(path)
      save_output(:docx, path)
    end

    # Get HTML output as text
    # @return [String] HTML content
    def to_html_text
      output(:html)
    end

    # Save HTML to file
    # @param path [String] destination path
    # @return [String] path
    def to_html_file(path)
      save_output(:html, path)
    end

    # Get Markdown output as text
    # @return [String] Markdown content
    def to_md_text
      output(:md)
    end

    alias to_markdown_text to_md_text

    # Save Markdown to file
    # @param path [String] destination path
    # @return [String] path
    def to_md_file(path)
      save_output(:md, path)
    end

    alias to_markdown_file to_md_file

    # Get LaTeX ZIP as bytes
    # @return [String] binary ZIP content
    def to_tex_zip_bytes
      output(:'tex.zip')
    end

    # Save LaTeX ZIP to file
    # @param path [String] destination path
    # @return [String] path
    def to_tex_zip_file(path)
      save_output(:'tex.zip', path)
    end

    # Get LaTeX PDF as bytes
    # @return [String] binary PDF content
    def to_latex_pdf_bytes
      output(:latex_pdf)
    end

    # Save LaTeX PDF to file
    # @param path [String] destination path
    # @return [String] path
    def to_latex_pdf_file(path)
      save_output(:latex_pdf, path)
    end

    # Get PowerPoint as bytes
    # @return [String] binary PPTX content
    def to_pptx_bytes
      output(:pptx)
    end

    # Save PowerPoint to file
    # @param path [String] destination path
    # @return [String] path
    def to_pptx_file(path)
      save_output(:pptx, path)
    end

    # Get all available outputs
    #
    # @return [Hash<Symbol, String>] format => url mapping
    def available_outputs
      refresh_status unless completed?
      return {} unless @status_data&.dig('outputs')

      @status_data['outputs'].transform_keys(&:to_sym)
    end

    # Inspect
    # @return [String]
    def inspect
      "#<Mathpix::Conversion id=#{conversion_id} status=#{status}>"
    end

    private

    # Refresh status from API
    def refresh_status
      @status_data = client.get_conversion_status(conversion_id)
    end

    # Get output URL for format
    #
    # @param format [String] format name
    # @return [String] download URL
    def output_url(format)
      urls = @status_data&.dig('outputs') || {}
      urls[format] || urls[format.to_s] ||
        raise(Error, "Output format '#{format}' not available. Available: #{urls.keys.join(', ')}")
    end
  end
end
