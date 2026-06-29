# frozen_string_literal: true

source 'https://rubygems.org'

# Build the dependency set from the gemspec in this repo.
gemspec

# Optional: load MATHPIX_* from a local .env when present (bin/mathpix-mcp uses it).
gem 'dotenv', '~> 3.2', require: false

group :development, :test do
  gem 'bundler-audit', '~> 0.9', require: false
  gem 'rake', '~> 13.2'
  gem 'rspec', '~> 3.13'
  gem 'rubocop', '~> 1.72', require: false
  gem 'rubocop-rake', '~> 0.6', require: false
  gem 'rubocop-rspec', '~> 3.4', require: false
end
