module Query
  class Operator
    REGISTRY = { }

    def self.op(name)
      return name if name.is_a?(self)
      REGISTRY[name.to_s] or raise "No operator: #{name}"
    end

    def self.define(name, negated, options)
      self.new(name, negated, options)
    end

    def self.register(name, op)
      REGISTRY[name.to_s] = op
    end

    def initialize(name, negated, options)
      @name = name
      @negated = negated
      @options = options
      self.class.register(name, self)
    end

    def negate
      self.class.op(@negated)
    end

    def arity
      @options[:arity] || 0
    end

    def unary?
      arity == 1
    end

    def commutative?
      !@options[:non_commutative]
    end

    def argtypes
      @argtypes ||=
        (if @options[:argtype].is_a?(Array)
           @options[:argtype]
         elsif @options[:argtype]
           [@options[:argtype]]
         end).map { |type| Sql::Type.type(type) }
    end

    def typecheck!(args)
      !self.argtypes ||
      self.argtypes.any { |argtype|
        args.all? { |arg|
          arg.type.type_match?(argtype)
        }
      }
    end

    def result_type(args)
      @options[:result] || args.first.type
    end

    def to_s
      @name
    end
  end
end
