module Query
  class ListgameParser
    def self.fragment(fragment)
      require 'query/ast/ast_builder'
      require 'query/ast/ast_translator'
      require 'query/ast/ast_fixup'
      require 'grammar/query_body'

      raw_parse = ::Grammar::QueryBody.new.parse(fragment.to_s)
      STDERR.puts("Fragment raw_parse: #{raw_parse.inspect}")
      ast = AST::ASTBuilder.new.apply(raw_parse)
      STDERR.puts("Fragment AST: #{ast.inspect}")
      ast = AST::ASTTranslator.apply(ast)
      STDERR.puts("Fragment translated AST: #{ast.inspect}")
      ast
    end

    def self.parse(default_nick, query)
      require 'query/ast/ast_builder'
      require 'query/ast/ast_translator'
      require 'query/ast/ast_fixup'
      require 'grammar/query'

      raw_parse = ::Grammar::Query.new.parse(query.to_s)
      STDERR.puts("raw_parse: #{raw_parse.inspect}")

      ast = AST::ASTBuilder.new.apply(raw_parse)
      STDERR.puts("AST: #{ast}")

      ast.with_context {
        ::Query::NickExpr.with_default_nick(default_nick) {
          translated_ast = AST::ASTTranslator.apply(ast)
          STDERR.puts("Resolved AST: #{translated_ast}")

          fixed_ast = AST::ASTFixup.result(default_nick, translated_ast)
          STDERR.puts("Fixed AST: #{fixed_ast}, head: #{fixed_ast.head}")
          fixed_ast
        }
      }
    end
  end
end
