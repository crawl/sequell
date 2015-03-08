$:.push('src')
require 'bundler/setup'
require 'helper'
require 'parslet'
require 'parslet/rig/rspec'

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
end
