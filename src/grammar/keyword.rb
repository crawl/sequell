# encoding: UTF-8
require 'parslet'

module Grammar
  class Keyword < Parslet::Parser
    root(:keyword_expr)

    rule(:keyword_expr) {
      keyword_alternates | keyword_term
    }

    rule(:keyword_alternates) {
      (keyword_term >>
        (str("|") >> keyword_term).repeat(1)).as(:or)
    }

    rule(:keyword_term) {
      str("!") >> keyword_term.as(:negated) |
        keyword_unprefixed
    }

    rule(:keyword_unprefixed) {
      parenthesized_keywords | keyword_atom
    }

    rule(:parenthesized_keywords) {
      str("(") >> keyword_expr.as(:parentheses) >> str(")")
    }

    rule(:keyword_atom) {
      (keyword_nick | keyword_any).as(:keyword)
    }

    rule(:keyword_nick) {
      (match["@:"].repeat(1) >> Nick.new.nick_atom_strict).as(:nick)
    }

    rule(:keyword_any) {
      match['\\\\0-9a-zA-Z_\[\]$,.:&*+[^\x00-\x7f]-'].repeat(1)
    }

    rule(:space) {
      match('\s').repeat(1)
    }
  end
end
