# frozen_string_literal: true

RSpec.describe Mathpix::Client do
  subject(:client) { described_class.new(config) }

  let(:config) do
    Mathpix::Configuration.new.tap do |c|
      c.app_id = 'id'
      c.app_key = 'key'
    end
  end

  describe '#extract_error_message' do
    it 'prefers error_info.message' do
      payload = { 'error_info' => { 'message' => 'boom' }, 'error' => 'other' }
      expect(client.send(:extract_error_message, payload)).to eq('boom')
    end

    it 'falls back to the error field' do
      expect(client.send(:extract_error_message, { 'error' => 'oops' })).to eq('oops')
    end

    it 'returns nil for a non-hash payload' do
      expect(client.send(:extract_error_message, 'nope')).to be_nil
    end
  end

  describe '#build_conversion_formats' do
    it 'maps known formats and always enables markdown' do
      result = client.send(:build_conversion_formats, formats: %w[docx latex])
      expect(result).to eq('docx' => true, 'tex.zip' => true, 'md' => true)
    end

    it 'drops unknown formats but still enables markdown' do
      expect(client.send(:build_conversion_formats, formats: %w[text])).to eq('md' => true)
    end
  end
end
