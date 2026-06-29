# frozen_string_literal: true

module Mathpix
  # Chemistry capture builder
  class Chemistry
    def initialize(client, image_path)
      @client = client
      @image_path = image_path
      @options = {
        chemistry: true,
        include_smiles: true
      }
    end

    # Enable SMILES output
    # @return [self]
    def with_smiles
      @options[:include_smiles] = true
      self
    end

    # Enable InChI output
    # @return [self]
    def with_inchi
      @options[:include_inchi] = true
      self
    end

    # Enable molecular formula
    # @return [self]
    def with_molecular_formula
      @options[:include_molecular_formula] = true
      self
    end

    # Enable stereochemistry detection
    # @return [self]
    def with_stereochemistry
      @options[:detect_stereochemistry] = true
      self
    end

    # Set confidence threshold
    # @param threshold [Float] minimum confidence
    # @return [self]
    def with_confidence(threshold)
      @options[:confidence_threshold] = threshold
      self
    end

    # Add metadata
    # @param metadata [Hash] metadata
    # @return [self]
    def with_metadata(**metadata)
      @options[:metadata] = metadata
      self
    end

    # Execute capture
    # @return [Result]
    def capture
      @client.snap(@image_path, **@options)
    end

    alias call capture
    alias run capture
  end
end
