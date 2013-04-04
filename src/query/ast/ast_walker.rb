module Query
  module AST
    class ASTWalker
      def self.map_keywords(ast, &block)
        ast.arguments = ast.arguments.map { |arg|
          map_keywords(arg, &block)
        }.compact
        if ast.kind == :keyword
          return block.call(ast)
        end
        ast
      end
    end
  end
end
