require 'sql/type_predicates'

module Sql
  class FunctionDef
    include TypePredicates

    def initialize(cfg)
      @cfg = cfg
    end

    def type
      @cfg['type']
    end

    def expr
      @cfg['expr']
    end

    def return_type
      @cfg['return'] || self.type
    end
  end
end
