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
    attr_accessor :type, :summarisable, :expr, :display_format

    def initialize(name, cfg)
      @name = name
      @cfg = cfg
      if @cfg.is_a?(String)
        @cfg = { 'type' => @cfg }
      end
      @type = Type.type(@cfg['type'])
      @summarisable = @cfg['summarisable']
      @display_format = @cfg['display-format']
      @preserve_field_type = @cfg['preserve-field-type']
      @expr = @cfg['expr']
      @return_type = Type.type(@cfg['return'] || '*')
    end

    def return_type(field)
      field = Sql::Field.field(field)
      return field.type if preserve_field_type?
      return @return_type unless @return_type.any?
      field.type
    end

    def preserve_field_type?
      @preserve_field_type
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
  end
end
