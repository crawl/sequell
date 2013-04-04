module Query
  class ListgameParser
    def self.parse(default_nick, query)
      require 'query/ast_transform'
      require 'query/ast_fixup'
      require 'grammar/query'

      ast = Query::ASTTransform.new.apply(
        ::Grammar::Query.new.parse(query.to_s))
      ASTFixup.new.apply(ast)
    end
  end
end
