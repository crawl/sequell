require 'spec_helper'
require 'tpl/template_parser'
require 'parslet/rig/rspec'

describe Tpl::TemplateParser do
  subject { Tpl::TemplateParser.new }

  TEMPLATES = [
    'Hi $1',
    'Hi $*',
    'Hi ${*:-n}',
    'Hi ${cow:-$1}'
  ]
end
