# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

RSpec.describe Mathpix::MCP::Tools::BatchConvertTool do
  let(:client) do
    Class.new do
      def snap(path, **)
        raise Mathpix::APIError.new('boom', status: 400) if path.include?('bad')

        Mathpix::Result.new('latex_styled' => "L:#{path}", 'text' => "T:#{path}", 'confidence' => 0.9)
      end
    end.new
  end

  let(:dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(dir) }

  it 'processes sequentially, preserving order and capturing per-item errors' do
    results = described_class.process_batch_sequential(client, %w[a bad c], [:latex], dir)

    expect(results.map { |r| r[:index] }).to eq([0, 1, 2])
    expect(results.map { |r| r[:success] }).to eq([true, false, true])
    expect(results[1][:error]).to eq('boom')
  end

  it 'processes in parallel, preserving order and writing content to files' do
    results = described_class.process_batch_parallel(client, %w[a b bad d], [:latex], 2, dir)

    expect(results.map { |r| r[:index] }).to eq([0, 1, 2, 3])
    expect(results.map { |r| r[:success] }).to eq([true, true, false, true])
    # Recognized content is written to a file, not inlined.
    expect(results[0][:latex]).to be_nil
    expect(File.read(results[0][:saved_files]['latex'][:path])).to eq('L:a')
  end
end
