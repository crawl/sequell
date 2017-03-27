require 'sql/query_context'
require 'query/ast/keyed_option'

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
      debug{"Fragment '#{fragment.to_s}' raw_parse: #{raw_parse.inspect}"}
      ast = AST::ASTBuilder.new.apply(raw_parse)
      if ast.is_a?(Hash)
        raise "Could not understand fragment '#{query_text}'. This is a bug."
      end
      AST::ASTTranslator.apply(ast)
    rescue Parslet::ParseFailed => error
      raise("Broken query near '" +
        fragment.to_s[error_place(error.cause)..-1] + "'")
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
        debug{"Query '#{query_text}': raw_parse: #{raw_parse.inspect}"}

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

            fixed_ast = AST::ASTFixup.result(translated_ast)

            if fixed_ast.option(:count) && !fixed_ast.option(:json) &&
                !fixed_ast.key_value(:fmt)
              ast.keys <<
                ::Query::AST::KeyedOption.new('fmt', '$name L$xl $char ($src)$(and $x " [$x]")')
            end

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
      ([cause.pos.bytepos] + (cause.children || []).map { |child|
        error_place(child)
      }).max
    end
  end
end
