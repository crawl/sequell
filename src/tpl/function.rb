require 'tpl/tplike'

module Tpl
  class Function
    include Tplike

    attr_reader :name, :parameters, :rest, :body

    def initialize(name, parameters, rest, body)
      @name = name
      @name = @name.identifier if @name.respond_to?(:identifier)
      @parameters = parameters ? parameters.map(&:identifier) : ['_']
      @rest = Tpl::Fragment.identifier(rest)
      @body = body
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

    def parameter_str
      base = @parameters.map(&:to_s)
      if @rest
        base << '.' << @rest.to_s
      end
      base.join(' ')
    end

    def to_s
      "$(fn #{name ? name + ' ' : ''}(#{parameter_str}) #{body})"
    end
  end
end
