# frozen_string_literal: true

module Mathpix
  # Document processing builder (PDF, DOCX, PPTX)
  class Document
    attr_reader :client, :document_path, :options

    def initialize(client, document_path)
      @client = client
      @document_path = document_path
      @options = {}
    end

    # Set output formats
    # @param formats [Array<Symbol>] format names
    # @return [self]
    # @example
    #   doc.with_formats(:markdown, :latex, :docx)
    def with_formats(*formats)
      @options[:formats] = formats.flatten
      self
    end

    # Enable table extraction
    # @param options [Hash] table options
    # @return [self]
    def with_tables(**options)
      @options[:include_table_html] = true
      @options.merge!(options)
      self
    end

    # Enable diagram extraction
    # @return [self]
    def with_diagrams
      @options[:include_diagram_svg] = true
      self
    end

    # Set quality level
    # @param level [Symbol] :low, :medium, :high
    # @return [self]
    def quality(level)
      @options[:quality] = level
      self
    end

    # Enable line-level data (bounding boxes)
    # @return [self]
    def with_line_data
      @options[:include_line_data] = true
      self
    end

    # Enable word-level data (bounding boxes)
    # @return [self]
    def with_word_data
      @options[:include_word_data] = true
      self
    end

    # Set page range for processing
    # @param start_page [Integer] first page (1-indexed)
    # @param end_page [Integer, nil] last page (nil = all)
    # @return [self]
    def pages(start_page, end_page = nil)
      @options[:page_ranges] = { start: start_page, end: end_page }
      self
    end

    # Execute document conversion (async operation).
    #
    # The whole document is uploaded in a single request — the Mathpix /v3/pdf
    # endpoint paginates large PDFs server-side.
    #
    # @return [DocumentConversion] conversion object (async)
    # @example
    #   conversion = Mathpix::Document.new(client, 'paper.pdf')
    #     .with_formats(:markdown, :latex)
    #     .convert
    #   conversion.wait_until_complete
    #   conversion.save_markdown('output.md')
    def convert
      doc_type = detect_document_type
      conversion_id = client.convert_document(
        document_path: document_path,
        document_type: doc_type,
        **options
      )
      DocumentConversion.new(client, conversion_id, document_path, doc_type)
    end

    alias call convert
    alias run convert

    private

    # Detect document type from file extension
    # @return [Symbol] :pdf, :docx, :pptx
    def detect_document_type
      ext = File.extname(document_path).downcase
      case ext
      when '.pdf' then :pdf
      when '.docx' then :docx
      when '.pptx' then :pptx
      else
        raise InvalidImageError.new(
          "Unsupported document format: #{ext}",
          recommended_format: 'pdf, docx, pptx'
        )
      end
    end
  end

  # Document Conversion Result (async operation)
  #
  # Polls Mathpix API until conversion completes
  class DocumentConversion
    attr_reader :client, :conversion_id, :document_path, :document_type

    def initialize(client, conversion_id, document_path, document_type)
      @client = client
      @conversion_id = conversion_id
      @document_path = document_path
      @document_type = document_type
    end

    # Wait for conversion to complete
    #
    # @param max_wait [Integer] maximum wait time in seconds
    # @param poll_interval [Float] seconds between polls
    # @return [self]
    def wait_until_complete(max_wait: 600, poll_interval: 3.0)
      start_time = Time.now

      loop do
        status_data = client.get_document_status(conversion_id)
        status = status_data['status']

        case status
        when 'completed'
          @result = DocumentResult.new(build_result_data(status_data), document_path, document_type)
          return self
        when 'error', 'failed'
          raise ConversionError.new(
            "Document conversion failed: #{extract_status_error(status_data)}",
            conversion_id: conversion_id,
            conversion_status: status
          )
        else
          # Any non-terminal status keeps polling. Mathpix reports several
          # intermediate states (received, loaded, split, processing,
          # pending, ...) — we only stop on 'completed' or an error.
          elapsed = Time.now - start_time
          if elapsed > max_wait
            raise TimeoutError, "Document conversion timed out after #{max_wait}s (last status: #{status})"
          end

          sleep poll_interval
        end
      end
    end

    # Get result (must wait_until_complete first)
    # @return [DocumentResult]
    def result
      @result || raise(ConversionError, 'Conversion not yet complete. Call wait_until_complete first.')
    end

    # Convenience method: wait and get result
    # @return [DocumentResult]
    def complete!
      wait_until_complete
      result
    end

    # Save markdown output
    # @param path [String] output file path
    def save_markdown(path)
      complete! unless @result
      @result.save_markdown(path)
    end

    # Save LaTeX output
    # @param path [String] output file path
    def save_latex(path)
      complete! unless @result
      @result.save_latex(path)
    end

    # Save HTML output
    # @param path [String] output file path
    def save_html(path)
      complete! unless @result
      @result.save_html(path)
    end

    # Save DOCX output
    # @param path [String] output file path
    def save_docx(path)
      complete! unless @result
      @result.save_docx(path)
    end

    private

    # Merge fetched output content into the status payload so DocumentResult
    # can expose markdown/html. The /v3/pdf/{id} status JSON never contains the
    # converted text — it must be fetched from the .{ext} endpoints.
    def build_result_data(status_data)
      data = status_data.dup
      data['markdown'] ||= fetch_output('mmd')
      data['html'] ||= fetch_output('html')
      data
    end

    def fetch_output(format)
      client.get_document_output(conversion_id, format)
    rescue Mathpix::Error
      nil
    end

    # Pull a descriptive failure reason from a Mathpix status payload.
    def extract_status_error(status_data)
      info = status_data['error_info']
      (info && (info['message'] || info['id'])) ||
        status_data['error'] ||
        'unknown error'
    end
  end

  # Document Result object
  #
  # Represents processed document with extracted content
  class DocumentResult < Result
    attr_reader :document_path, :document_type

    def initialize(data, document_path = nil, document_type = nil)
      super(data)
      @document_path = document_path
      @document_type = document_type
    end

    # Get all pages
    # @return [Array<Hash>] page data
    def pages
      data['pages'] || []
    end

    # Get page count
    # @return [Integer]
    def page_count
      pages.length
    end

    # Processing time (seconds if reported by the conversion, else nil)
    # @return [Numeric, nil]
    def processing_time
      data['total_processing_time'] || data['processing_time'] || processing_time_ms
    end

    # Get all equations across all pages
    # @return [Array<String>]
    def equations
      pages.flat_map { |p| p['equations'] || [] }
    end

    # Get all tables across all pages
    # @return [Array<Hash>]
    def tables
      pages.flat_map { |p| p['tables'] || [] }
    end

    # Get all diagrams across all pages
    # @return [Array<Hash>]
    def diagrams
      pages.flat_map { |p| p['diagrams'] || [] }
    end

    # Get markdown output
    # @return [String, nil]
    def markdown
      data['markdown'] || data['mmd']
    end

    # Get LaTeX output
    # @return [String, nil]
    def latex
      data['latex']
    end

    # Get HTML output
    # @return [String, nil]
    def html
      data['html']
    end

    # Save markdown to file
    # @param path [String] output file path
    def save_markdown(path)
      File.write(path, markdown) if markdown
    end

    # Save LaTeX to file
    # @param path [String] output file path
    def save_latex(path)
      File.write(path, latex) if latex
    end

    # Save HTML to file
    # @param path [String] output file path
    def save_html(path)
      File.write(path, html) if html
    end

    # Save DOCX output to file
    # @param path [String] output file path
    def save_docx(path)
      if data['docx_url']
        docx_data = client.download(data['docx_url'])
        File.binwrite(path, docx_data)
      elsif data['docx_data']
        File.binwrite(path, data['docx_data'])
      end
    end

    # Check if document is a specific type
    # @return [Boolean]
    def pdf?
      document_type == :pdf
    end

    def docx?
      document_type == :docx
    end

    def pptx?
      document_type == :pptx
    end
  end

  # Alias PDF class to Document for backward compatibility
  PDF = Document
  PDFResult = DocumentResult
end
