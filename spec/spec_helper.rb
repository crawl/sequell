$:.push('src')
require 'bundler/setup'
require 'helper'
require 'parslet'
require 'parslet/rig/rspec'

ENV['HENZELL_SQL_QUERIES'] = 'y'

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
end
