# frozen_string_literal: true

require_relative 'lib/mathpix/version'

Gem::Specification.new do |s|
  s.name        = 'mathpix-mcp'
  s.version     = Mathpix::VERSION
  s.authors     = ['Georgios Douzas']
  s.email       = ['georgios.douzas@gmail.com']
  s.summary     = 'Mathpix OCR MCP server (stdio + HTTP)'
  s.description = <<~DESC
    A Model Context Protocol server for Mathpix OCR, over stdio or Streamable
    HTTP (bearer-token auth). Exposes tools to convert images and PDF/DOCX/PPTX
    documents to LaTeX and Markdown, with descriptive errors and optional file
    output for large results.
  DESC
  s.licenses = ['MIT']
  s.homepage = 'https://github.com/georgedouzas/mathpix-mcp'

  s.required_ruby_version = '>= 3.2.0'

  s.files = Dir['lib/**/*.rb', 'bin/*', 'config.ru', 'README.md', 'LICENSE', 'CHANGELOG.md']
  s.bindir        = 'bin'
  s.executables   = %w[mathpix-mcp mathpix-mcp-http]
  s.require_paths = ['lib']

  # base64 is no longer a default gem on Ruby 3.4+, so it must be declared.
  s.add_dependency 'base64', '>= 0.1'
  s.add_dependency 'mcp', '>= 0.9.2'
  # HTTP (Streamable HTTP) transport. rack is autoloaded by the SDK transport;
  # puma serves it via bin/mathpix-mcp-http. (stdio mode loads neither.)
  s.add_dependency 'puma', '>= 8.0.2'
  s.add_dependency 'rack', '~> 3.1'

  s.metadata['rubygems_mfa_required'] = 'true'
  s.metadata['source_code_uri'] = 'https://github.com/georgedouzas/mathpix-mcp'
  s.metadata['changelog_uri'] = 'https://github.com/georgedouzas/mathpix-mcp/blob/main/CHANGELOG.md'
  s.metadata['bug_tracker_uri'] = 'https://github.com/georgedouzas/mathpix-mcp/issues'
end
