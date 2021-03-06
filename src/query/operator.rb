require 'ostruct'
require 'query/operator_type_map'

module Query
  class Operator
    include Comparable

    REGISTRY = { }

    def self.op(name)
      return name if name.is_a?(self)
      REGISTRY[name.to_s] or raise "No operator: #{name}"
    end

    def self.define(*args)
      self.new(*args)
    end

    def self.register(name, op)
      REGISTRY[name.to_s] = op
    end

    attr_reader :name, :polymorphic_form

    def initialize(name, negated, sql_operator, options)
      @name = name
      @negated = negated
      @sql_operator = sql_operator
      @options = OpenStruct.new(options)
      self.class.register(name, self)
    end

    def negatable?
      @options.negated
    end

    def relational?
      @options.relational
    end

    def precedence
      @options.precedence || 0
    end

    def sql_operator
      polymorphic_form || @sql_operator || " #{@name.upcase} "
    end

    def negate
      raise "Cannot negate operator: #{self}" unless @negated
      self.class.op(@negated)
    end

    def arity
      @options.arity || 0
    end

    def unary?
      arity == 1
    end

    def commutative?
      !@options.non_commutative
    end

    def can_coalesce?
      commutative? && arity == 0
    end

    def argtypes
      @argtypes ||= OperatorTypeMap[@options.argtypes || @options.argtype, @options.result]
    end

    def result_type(args)
      @polymorphic_form = argtypes.polymorphic_form(args) || self.sql_operator
      argtypes.result_type(args)
    end

    def equality?
      self == '=' || self == '!='
    end

    def equal?
      self == '='
    end

    def <=> (other)
      return 1 unless other
      self.precedence <=> self.class.op(other).precedence
    end

    def == (other)
      @name.to_s == other.to_s
    end

    def === (ops)
      if ops.is_a?(Enumerable)
        ops.any? { |op| self == op }
      else
        self == ops
      end
    end

    def to_sql
      self.sql_operator
    end

    def display_string
      (@options.display_string || @name).to_s
    end

    def to_s
      @name.to_s
    end

    def coerce_argument_types(args)
      argtypes.coerce(args, arity)
    end

  private

    def lookup_types(type_map)
      OperatorTypeMap[type_map]
    end

    def polymorphic?
    end

    def polymorphic_coerce!(args)

    end

    def simple_coerce!(args)
    end
  end
end
