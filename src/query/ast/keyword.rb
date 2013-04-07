require 'query/ast/modifier'

module Query
  module AST
    class Keyword < Modifier
      def initialize(keyword)
        super(:keyword, keyword)
      end

      def meta?
        false
      end
    end
  end
end
