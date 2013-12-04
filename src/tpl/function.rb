require 'tpl/tplike'

module Tpl
  class Function
    include Tplike

    attr_reader :name, :parameters, :rest, :body_forms

    def initialize(name, parameters, rest, body_forms)
      @name = name
      @name = @name.identifier if @name.respond_to?(:identifier)
      @parameters = parameters ? parameters.map(&:identifier) : ['_']
      @rest = Tpl::Fragment.identifier(rest)
      @body_forms = body_forms
    end

    def arity
      [@parameters.size, @rest ? -1 : @parameters.size]
    end

    def call(scope, *args)
      Funcall.new(self, *args).eval(scope)
    end

    # A function evaluates to itself; it must be funcalled to do
    # anything useful
    def eval(scope)
      self
    end

    def eval_body_in_scope(scope)
      res = nil
      @body_forms.each { |form|
        res = eval_value(form, scope)
      }
      res
    end

    def parameter_str
      base = @parameters.map(&:to_s)
      if @rest
        base << '.' << @rest.to_s
      end
      base.join(' ')
    end

    def to_s
      "$(fn #{name ? name + ' ' : ''}(#{parameter_str}) #{body_forms.join(' ')})"
    end
  end
end
