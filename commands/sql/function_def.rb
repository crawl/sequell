require 'sql/type_predicates'

module Sql
  class FunctionDef
    include TypePredicates

    attr_reader :name

    def initialize(name, cfg)
      @name = name
      @cfg = cfg
      if @cfg.is_a?(String)
        @cfg = { 'type' => @cfg }
      end
    end

    def type
      @cfg['type']
    end

    def summarisable?
      @cfg['summarisable']
    end

    def display_format
      @cfg['display-format']
    end

    def expr
      @cfg['expr'] || "#{@name}(%s)"
    end

    def return_type
      @cfg['return'] || self.type
    end

    def to_s
      @name
    end
  end
end
