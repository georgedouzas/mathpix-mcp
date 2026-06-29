# frozen_string_literal: true

RSpec.describe Mathpix::MCP::Tools::SearchResultsTool do
  def text_of(response)
    response.content.first[:text]
  end

  def fake_client(results)
    Class.new do
      define_method(:recent) { |limit:| results }
    end.new
  end

  it 'downgrades to previews and adds a note when content exceeds the limit' do
    big = Array.new(3) do |i|
      Mathpix::Result.new('request_id' => "id#{i}", 'created' => 'now',
                          'latex_styled' => 'L' * 30_000, 'text' => 'T' * 30_000, 'confidence' => 0.9)
    end
    response = described_class.call(server_context: { mathpix_client: fake_client(big) }, include_content: true)
    data = JSON.parse(text_of(response))

    expect(data['note']).to include('exceeded the inline limit')
    expect(data['results'].first).to have_key('latex_preview')
    expect(data['results'].first).not_to have_key('latex')
  end

  it 'inlines full content when small' do
    small = [Mathpix::Result.new('request_id' => 'a', 'created' => 'now',
                                 'latex_styled' => 'x', 'text' => 'y', 'confidence' => 0.9)]
    response = described_class.call(server_context: { mathpix_client: fake_client(small) }, include_content: true)
    data = JSON.parse(text_of(response))

    expect(data['note']).to be_nil
    expect(data['results'].first['latex']).to eq('x')
  end
end
