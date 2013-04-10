require 'sql/query_context'

module Query
  class ListgameParser
    def self.fragment(fragment)
      require 'query/ast/ast_builder'
      require 'query/ast/ast_translator'
      require 'query/ast/ast_fixup'
      require 'grammar/query_body'

      raw_parse =
        ::Grammar::QueryBody.new.parse(
          fragment.to_s,
          reporter: Parslet::ErrorReporter::Deepest.new)
      debug{"Fragment raw_parse: #{raw_parse.inspect}"}
      ast = AST::ASTBuilder.new.apply(raw_parse)
      #debug{"Fragment AST: #{ast.inspect}"}
      if ast.is_a?(Hash)
        raise "Could not understand fragment '#{query_text}'. This is a bug."
      end
      ast = AST::ASTTranslator.apply(ast)
      #debug{"Fragment translated AST: #{ast.inspect}"}
      ast
    end

    def self.parse(default_nick, query, add_context=false)
      require 'query/ast/ast_builder'
      require 'query/ast/ast_translator'
      require 'query/ast/ast_fixup'
      require 'grammar/query'

      query_text = query.to_s
      query_text = query_with_context(query_text) if add_context

      begin
        debug{"Parsing query: '#{query_text}', enc: #{query_text.encoding}"}
        raw_parse =
          ::Grammar::Query.new.parse(
            query_text,
            reporter: Parslet::ErrorReporter::Deepest.new)
        #debug{"raw_parse: #{raw_parse.inspect}"}

        ast = AST::ASTBuilder.new.apply(raw_parse)
        if ast.is_a?(Hash)
          debug{"AST: #{ast}"}
          raise "Could not understand query '#{query_text}'. This is a bug."
        end

        ast.with_context {
          ::Query::NickExpr.with_default_nick(default_nick) {
            ast.default_nick = default_nick

            translated_ast = AST::ASTTranslator.apply(ast)
            #debug{"Resolved AST: #{translated_ast}"}

            fixed_ast = AST::ASTFixup.result(default_nick, translated_ast)
            #debug{"Fixed AST: #{fixed_ast}, head: #{fixed_ast.head}"}
            fixed_ast
          }
        }

      rescue Parslet::ParseFailed => error
        raise("Broken query near '" +
              query_text[error_place(error.cause)..-1] + "'")
      end
    end

    def self.query_with_context(query, context='!lg')
      return query if Sql::QueryContext.names.any? { |name|
        query.index(name + ' ') == 0
      }
      context + ' ' + query
    end

    def self.error_place(cause)
      ([cause.pos] + (cause.children || []).map { |child|
        error_place(child)
      }).max
    end
  end
end
