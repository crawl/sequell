require 'tpl/template_parser'
require 'tpl/template_builder'

module Tpl
  class TemplateOptions
    attr_accessor :functions, :subcommands

    def self.allow_all
      self.new(subcommands: true, functions: true)
    end

    def self.no_subcommands
      self.new(subcommands: false, functions: true)
    end

    def initialize(options={})
      @subcommands = options[:subcommands]
      @functions = options[:functions]
    end

    alias :functions? :functions
    alias :subcommands? :subcommands
  end

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

    def self.allow_subcommands?
      options.subcommands?
    end

    def self.allow_functions?
      options.functions?
    end

    def self.options
      @options || default_options
    end

    def self.without_subcommands(&block)
      self.with_options(TemplateOptions.no_subcommands, &block)
    end

    def self.with_options(new_options=nil)
      current_options = @options
      begin
        @options = new_options || default_options
        yield
      ensure
        @options = current_options
      end
    end

    def self.default_options
      @default_options ||= TemplateOptions.allow_all
    end

    def self.function_executor
      require 'tpl/function_executor'
      require 'tpl/function_defs'
      @function_executor ||= Tpl::FunctionExecutor
    end
  end
end
