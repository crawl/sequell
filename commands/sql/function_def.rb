require 'sql/type_predicates'

module Sql
  class FunctionDef
    include TypePredicates

    def initialize(name, cfg)
      @name = name
      @cfg = cfg
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
      @cfg['expr']
    end

    def return_type
      @cfg['return'] || self.type
    end
  end
end
