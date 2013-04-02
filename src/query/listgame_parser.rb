module Query
  class ListgameParser
    def self.parse(query)
      require 'query/ast_transform'
      require 'grammar/query'

      Query::ASTTransform.new.transform(
        Grammar::Query.new.parse(query.to_s))
    end
  end
end
