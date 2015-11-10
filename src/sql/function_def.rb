require 'sql/type'
require 'sql/type_predicates'
require 'sql/function_type'

module Sql
  class FunctionDef
    include TypePredicates

    def self.truncate(name, slab)
      slab = slab.to_i
      f = self.new(name, 'I')
      f.summarisable = true
      f.expr = "DIV(%s, #{slab}) * #{slab}"
      f
    end

    attr_reader :name, :id
    attr_accessor :argtypes, :summarisable, :expr, :display_format

    def initialize(name, cfg)
      @name = name
      @cfg = cfg
      @id = cfg['id'] || @name
      if @cfg.is_a?(String)
        @cfg = { 'type' => @cfg }
      end
      @argtypes = Sql::FunctionType.new(@cfg['type'] || @cfg['types'],
                                        @cfg['return'])
      @summarisable = @cfg['summarisable']
      @display_format = @cfg['display-format']
      @preserve_unit = @cfg['preserve-unit']
      @unit = @cfg['unit']
      @expr = @cfg['expr']
    end

    def count?
      @cfg['count']
    end

    def arity
      @arity ||= @argtypes.size
    end

    def return_type(args)
      @argtypes.return_type(self.name, args)
    end

    def typecheck!(args)
      @argtypes.type_match(self.name, args) or
        raise Sql::TypeError.new("Cannot apply to #{args}")
    end

    def coerce_argument_types(args)
      @argtypes.coerce_argument_types(self.name, args)
    end

    def argument_types(types)
      types = ['*'] if types.nil?
      types = [types] unless types.is_a?(Array)
      types.map { |t| Type.type(t) }
    end

    def preserve_unit?
      @preserve_unit
    end

    def summarisable?
      @summarisable
    end

    def expr
      @expr || "#{@name}(%s)"
    end

    def === (name)
      @name == name
    end

    def to_s
      @name.to_s
    end

  private
    def find_return_type(expr)
      return @return_type unless @return_type.any?
      expr.type
    end

    def unit(expr)
      return expr.unit if preserve_unit?
      @unit
    end
  end
end
