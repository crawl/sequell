require 'tree/node'

module Tree
  class SortExpr < Node
    def self.sort(*expressions)
      self.new(expressions)
    end

    def initialize(sorts)
      @sorts = sorts
    end
  end
end
