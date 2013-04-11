require 'tpl/template_parser'
require 'tpl/template_builder'

module Tpl
  class Template
    def self.template_eval(text, provider=nil, &block)
      template(text).eval(provider || block)
    end

    def self.template(text)
      template = TemplateBuilder.new.apply(TemplateParser.new.parse(text))
      if template.is_a?(Hash)
        STDERR.puts("Broken template parse: #{template.inspect}")
        raise "Could not parse template: #{text}"
      end
      template
    rescue Parslet::ParseFailed
      raise "Invalid template: #{text}"
    end
  end
end
