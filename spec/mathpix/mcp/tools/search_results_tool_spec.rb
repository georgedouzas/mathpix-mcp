# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

RSpec.describe Mathpix::MCP::Tools::SearchResultsTool do
  def text_of(response)
    response.content.first[:text]
  end

  def fake_client(results)
    Class.new do
      define_method(:recent) { |limit:| results }
    end.new
  end

  def call(results, **opts)
    response = described_class.call(server_context: { mathpix_client: fake_client(results) }, **opts)
    JSON.parse(text_of(response))
  end

  let(:dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(dir) }

  it 'always returns previews inline and never the full content' do
    big = Array.new(3) do |i|
      Mathpix::Result.new('request_id' => "id#{i}", 'created' => 'now',
                          'latex_styled' => 'L' * 30_000, 'text' => 'T' * 30_000, 'confidence' => 0.9)
    end
    first = call(big, include_content: true, output_dir: dir)['results'].first

    expect(first).to have_key('latex_preview')
    expect(first).not_to have_key('latex')
    expect(first['latex_preview'].length).to be <= 110
  end

  it 'writes full content to files when include_content is true' do
    small = [Mathpix::Result.new('request_id' => 'a', 'created' => 'now',
                                 'latex_styled' => 'x', 'text' => 'y', 'confidence' => 0.9)]
    saved = call(small, include_content: true, output_dir: dir)['results'].first['saved_files']

    expect(File.read(saved['latex']['path'])).to eq('x')
    expect(File.read(saved['text']['path'])).to eq('y')
  end

  it 'omits saved_files when include_content is false' do
    small = [Mathpix::Result.new('request_id' => 'a', 'created' => 'now',
                                 'latex_styled' => 'x', 'text' => 'y', 'confidence' => 0.9)]
    first = call(small)['results'].first

    expect(first).not_to have_key('saved_files')
    expect(first['latex_preview']).to eq('x')
  end
end
