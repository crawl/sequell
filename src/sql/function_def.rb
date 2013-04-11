require 'sql/type'
require 'sql/type_predicates'

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

    attr_reader :name
    attr_accessor :argtypes, :summarisable, :expr, :display_format

    def initialize(name, cfg)
      @name = name
      @cfg = cfg
      if @cfg.is_a?(String)
        @cfg = { 'type' => @cfg }
      end
      @argtypes = argument_types(@cfg['type'])
      @summarisable = @cfg['summarisable']
      @display_format = @cfg['display-format']
      @preserve_unit = @cfg['preserve-unit']
      @unit = @cfg['unit']
      @expr = @cfg['expr']
      @return_type = Type.type(@cfg['return'] || '*')
    end

    def arity
      @arity ||= @argtypes.size
    end

    def type
      @return_type
    end

    def argument_types(types)
      types = ['*'] if types.nil?
      types = [types] unless types.is_a?(Array)
      types.map { |t| Type.type(t) }
    end

    def return_type(expr)
      find_return_type(expr).with_unit(unit(expr))
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
      @name
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
