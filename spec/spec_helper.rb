# frozen_string_literal: true

require 'mathpix'
require 'mathpix/mcp'

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
