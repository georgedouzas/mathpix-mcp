# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Mathpix::MCP::Tools::ConvertDocumentTool do
  describe '.preview_of' do
    it 'truncates long content and appends an ellipsis' do
      long = 'x' * (described_class::PREVIEW_CHARS + 50)
      preview = described_class.preview_of(long)

      expect(preview.length).to eq(described_class::PREVIEW_CHARS + 1)
      expect(preview).to end_with('…')
    end

    it 'returns short content unchanged' do
      expect(described_class.preview_of('short')).to eq('short')
    end

    it 'returns nil for nil' do
      expect(described_class.preview_of(nil)).to be_nil
    end
  end

  describe '.sibling_path' do
    it 'derives a sibling path with a new extension' do
      expect(described_class.sibling_path('/a/b/foo.md', 'html')).to eq('/a/b/foo.html')
    end
  end

  describe '.save_contents' do
    it 'writes markdown to the target and siblings for other formats' do
      Dir.mktmpdir do |dir|
        md_path = File.join(dir, 'out.md')
        saved = described_class.save_contents({ markdown: '# hi', html: '<h1>hi</h1>' }, md_path)

        expect(File.read(md_path)).to eq('# hi')
        expect(File.read(File.join(dir, 'out.html'))).to eq('<h1>hi</h1>')
        expect(saved[:markdown][:path]).to eq(md_path)
        expect(saved[:html][:path]).to eq(File.join(dir, 'out.html'))
        expect(saved[:markdown][:bytes]).to eq('# hi'.bytesize)
      end
    end
  end
end
