require 'ostruct'

module Query
  class Operator
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

    attr_reader :name

    def initialize(name, negated, sql_operator, options)
      @name = name
      @negated = negated
      @sql_operator = sql_operator
      @options = OpenStruct.new(options)
      self.class.register(name, self)
    end

    def sql_operator
      @sql_operator || " #{@name.upcase} "
    end

    def negate
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

    def argtypes
      @argtypes ||=
        (if @options.argtype.is_a?(Array)
           @options.argtype
         elsif @options.argtype
           [@options.argtype]
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
      Sql::Type.type(@options.result || args.first.type)
    end

    def equality?
      self == '=' || self == '!='
    end

    def equal?
      self == '='
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
      @options.display_string || @name
    end

    def to_s
      @name
    end
  end
end
