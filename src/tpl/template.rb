require 'tpl/template_parser'
require 'tpl/template_builder'
require 'tpl/function_defs'

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

  class TemplateError < StandardError
  end

  class TemplateParseError < TemplateError
    attr_reader :template
    def initialize(template)
      super("Template parse failed: #{template} (this is a bug)")
    end
  end
  class InvalidTemplateError < TemplateError
    attr_reader :template
    def initialize(template)
      super("Invalid template: #{template}")
    end
  end

  class Template
    def self.string(result)
      return result.to_a.join(' ') if result.is_a?(Enumerable)
      result
    end

    def self.template_eval(text, provider=nil, &block)
      provider ||= block
      eval(template(text), provider)
    end

    def self.template_eval_string(text, scope=nil, &block)
      string(template_eval(text, scope, &block))
    end

    def self.eval(template, scope)
      scope_with_function_lookup = lambda { |key|
        val = scope[key]
        val.nil? ? FunctionDef.global_function_value(key) : val
      }
      template.eval(scope_with_function_lookup)
    end

    def self.eval_string(template, scope)
      string(eval(template, scope))
    end

    def self.template(text)
      parse = TemplateParser.new.parse(text)
      template = TemplateBuilder.new.apply(parse)
      if template.is_a?(Hash)
        STDERR.puts("Broken template parse: #{template.inspect}")
        raise "Could not parse template: #{text}"
      end
      template
    rescue Parslet::ParseFailed
      raise TemplateError.new(text)
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
