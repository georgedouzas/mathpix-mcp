# frozen_string_literal: true

require_relative 'lib/mathpix/version'

Gem::Specification.new do |s|
  s.name        = 'mathpix-mcp'
  s.version     = Mathpix::VERSION
  s.authors     = ['Georgios Douzas']
  s.email       = ['georgios.douzas@gmail.com']
  s.summary     = 'Mathpix OCR MCP server (stdio)'
  s.description = <<~DESC
    A Model Context Protocol (stdio) server for Mathpix OCR. Exposes tools to
    convert images and PDF/DOCX/PPTX documents to LaTeX and Markdown, with
    descriptive errors and optional file output for large results.
  DESC
  s.licenses = ['MIT']

  s.required_ruby_version = '>= 3.2.0'

  s.files = Dir['lib/**/*.rb', 'bin/*', 'README.md', 'LICENSE', 'CHANGELOG.md']
  s.bindir        = 'bin'
  s.executables   = ['mathpix-mcp']
  s.require_paths = ['lib']

  # Runtime dependencies — minimal stdio MCP server.
  # base64 is no longer a default gem on Ruby 3.4+, so it must be declared.
  s.add_dependency 'base64', '>= 0.1'
  s.add_dependency 'mcp', '>= 0.9.2'

  s.metadata['rubygems_mfa_required'] = 'true'
end
