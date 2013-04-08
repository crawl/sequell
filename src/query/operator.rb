require 'ostruct'

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

    attr_reader :name

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
      @sql_operator || " #{@name.upcase} "
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

    def argtype(args)
      first_type = Sql::Type.type((args.first && args.first.type) || '*')
      chosen_type = Sql::Type.type(
        self.argtypes.find { |at|
          first_type.type_match?(at)
        } || raise(Sql::TypeError.new("Type mismatch: cannot apply #{self} to #{args.first}"))
      )
      args.reduce(chosen_type) { |type, arg|
        debug("Applying #{type} to #{arg.type} (#{arg})")
        type.applied_to(arg.type)
      }
    end

    def result_type(args)
      first_arg_type = (args.first && args.first.type) || '*'
      Sql::Type.type(@options.result || first_arg_type).applied_to(
        first_arg_type)
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
  end
end
