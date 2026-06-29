# frozen_string_literal: true

RSpec.describe Mathpix::Result do
  subject(:result) { described_class.new(data) }

  let(:data) do
    {
      'latex_styled' => 'x^2',
      'text' => 'x^2',
      'confidence' => 0.9,
      'position' => { 'top' => 1, 'left' => 2 },
      'created' => '2026-06-29',
      'line_data' => [{ 'text' => 'x^2' }]
    }
  end

  it 'reads latex_styled as latex' do
    expect(result.latex).to eq('x^2')
  end

  it 'exposes position' do
    expect(result.position).to eq('top' => 1, 'left' => 2)
  end

  it 'exposes timestamp, falling back to created' do
    expect(result.timestamp).to eq('2026-06-29')
  end

  it 'exposes line_data via lines_json' do
    expect(result.line_data).to eq([{ 'text' => 'x^2' }])
  end

  it 'returns an empty array for missing word_data' do
    expect(result.word_data).to eq([])
  end
end
