require 'query/ast/modifier'

module Query
  module AST
    class Keyword < Modifier
      def initialize(keyword)
        super(:keyword, keyword)
      end
    end
  end
end
