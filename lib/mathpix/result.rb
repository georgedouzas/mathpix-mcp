# frozen_string_literal: true

module Mathpix
  # OCR Result object
  class Result
    attr_reader :data, :source_path

    def initialize(data, source_path = nil)
      @data = data
      @source_path = source_path
    end

    # Get source URL if image was processed from URL
    #
    # @return [String, nil] URL if source was remote, nil otherwise
    def source_url
      return nil unless @source_path.is_a?(String)

      @source_path.start_with?('http://', 'https://') ? @source_path : nil
    end

    # Text result
    # @return [String, nil]
    def text
      data['text']
    end

    # LaTeX styled output
    # @return [String, nil]
    def latex
      data['latex_styled'] || data['latex']
    end

    alias latex_styled latex

    # Simplified LaTeX
    # @return [String, nil]
    def latex_simplified
      data['latex_simplified']
    end

    # MathML output
    # @return [String, nil]
    def mathml
      data['mathml']
    end

    # AsciiMath output
    # @return [String, nil]
    def asciimath
      data['asciimath']
    end

    # HTML output (may contain SVG)
    # @return [String, nil]
    def html
      data['html']
    end

    # Confidence score
    # @return [Float] 0.0-1.0
    def confidence
      data['confidence'] || 0.0
    end

    # Confidence rate (alternative)
    # @return [Float] 0.0-1.0
    def confidence_rate
      data['confidence_rate'] || confidence
    end

    # Created timestamp
    # @return [Time, nil]
    def created_at
      Time.parse(data['created']) if data['created']
    rescue ArgumentError
      nil
    end

    # Request ID
    # @return [String, nil]
    def request_id
      data['request_id']
    end

    # Processing time in milliseconds
    # @return [Integer, nil]
    def processing_time_ms
      data['processing_time_ms']
    end

    # Bounding box / position of the detected region, if the API returned one.
    # @return [Hash, nil]
    def position
      data['position']
    end

    # Raw capture timestamp (used by recent/search results).
    # @return [String, nil]
    def timestamp
      data['timestamp'] || data['created']
    end

    # Line-level data array (alias for lines_json).
    # @return [Array<Hash>]
    def line_data
      lines_json
    end

    # Word-level data array, if present.
    # @return [Array<Hash>]
    def word_data
      data['word_data'] || []
    end

    # Is content printed (vs handwritten)?
    # @return [Boolean]
    def printed?
      data['is_printed'] == true
    end

    # Is content handwritten?
    # @return [Boolean]
    def handwritten?
      data['is_handwritten'] == true
    end

    # Contains chart?
    # @return [Boolean]
    def chart?
      data['contains_chart'] == true
    end

    # Contains diagram?
    # @return [Boolean]
    def diagram?
      data['contains_diagram'] == true
    end

    # Contains table?
    # @return [Boolean]
    def table?
      data['contains_table'] == true
    end

    # Get metadata
    # @return [Hash]
    def metadata
      data['metadata'] || {}
    end

    # Get tags
    # @return [Array<String>]
    def tags
      data['tags'] || []
    end

    # --- Line-by-line data ---

    # Get line-by-line data with bounding boxes
    #
    # Requires snap(..., include_line_data: true)
    #
    # @return [Array<Line>] array of line objects
    def lines
      return [] unless data['line_data']

      @lines ||= data['line_data'].map { |line_data| Line.new(line_data) }
    end

    # Get lines as JSON array (raw data)
    # @return [Array<Hash>]
    def lines_json
      data['line_data'] || []
    end

    # Line data structure for bounding boxes and confidence
    class Line
      attr_reader :data

      def initialize(data)
        @data = data
      end

      # Line text content
      # @return [String]
      def text
        data['text'] || ''
      end

      # Line confidence
      # @return [Float]
      def confidence
        data['confidence'] || 0.0
      end

      # Bounding box coordinates [x, y, width, height]
      # @return [Array<Integer>, nil]
      def bbox
        data['bbox']
      end

      alias bounding_box bbox

      # Is this line handwritten?
      # @return [Boolean]
      def handwritten?
        data['type'] == 'handwriting'
      end

      # Is this line printed?
      # @return [Boolean]
      def printed?
        %w[printed print].include?(data['type'])
      end

      # LaTeX for this line
      # @return [String, nil]
      def latex
        data['latex']
      end

      # MathML for this line
      # @return [String, nil]
      def mathml
        data['mathml']
      end

      # Word-level data (if available)
      # @return [Array<Word>]
      def words
        return [] unless data['words']

        @words ||= data['words'].map { |word_data| Word.new(word_data) }
      end

      # Convert to hash
      # @return [Hash]
      def to_h
        data
      end

      # Inspect
      # @return [String]
      def inspect
        "#<Mathpix::Result::Line text=\"#{text&.[](0..30)}\" confidence=#{confidence}>"
      end
    end

    # Word data structure for fine-grained bounding boxes
    class Word
      attr_reader :data

      def initialize(data)
        @data = data
      end

      # Word text
      # @return [String]
      def text
        data['text'] || ''
      end

      # Word confidence
      # @return [Float]
      def confidence
        data['confidence'] || 0.0
      end

      # Word bounding box
      # @return [Array<Integer>, nil]
      def bbox
        data['bbox']
      end

      # Convert to hash
      # @return [Hash]
      def to_h
        data
      end

      # Inspect
      # @return [String]
      def inspect
        "#<Mathpix::Result::Word text=\"#{text}\" confidence=#{confidence}>"
      end
    end

    # Convert to hash
    # @return [Hash]
    def to_h
      data
    end

    # Convert to JSON
    # @return [String]
    def to_json(*)
      data.to_json(*)
    end

    # Inspect
    # @return [String]
    def inspect
      "#<Mathpix::Result confidence=#{confidence} text=#{text&.[](0..50)}>"
    end

    # --- Chemistry-specific methods ---

    # SMILES notation (chemistry)
    # @return [String, nil]
    def smiles
      text if chemistry?
    end

    # InChI notation (chemistry)
    # @return [String, nil]
    def inchi
      data['inchi']
    end

    # InChI Key (chemistry)
    # @return [String, nil]
    def inchikey
      data['inchikey']
    end

    # Molecular formula
    # @return [String, nil]
    def molecular_formula
      data['molecular_formula']
    end

    # Molecular name
    # @return [String, nil]
    def molecular_name
      data['molecular_name']
    end

    # Molecular weight
    # @return [Float, nil]
    def molecular_weight
      data['molecular_weight']
    end

    # Has stereochemistry?
    # @return [Boolean]
    def stereochemistry?
      data['has_stereochemistry'] == true || smiles&.include?('@')
    end

    # Is this a chemistry result?
    # @return [Boolean]
    def chemistry?
      molecular_formula || inchi || smiles&.match?(%r{^[A-Za-z0-9@\[\]()=#+\-\\/.]+$})
    end

    # --- Success/Failure ---

    # Was capture successful?
    # @return [Boolean]
    def success?
      !text.nil? && confidence >= 0.5
    end

    # Was capture a failure?
    # @return [Boolean]
    def failure?
      !success?
    end

    # Execute block if successful
    # @yield [self]
    # @return [self]
    def on_success
      yield self if success?
      self
    end

    # Execute block if failed
    # @yield [self]
    # @return [self]
    def on_failure
      yield self if failure?
      self
    end
  end
end
