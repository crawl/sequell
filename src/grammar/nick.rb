module Grammar
  class Nick < Parslet::Parser
    root(:nick_root)

    rule(:nick_root) {
      nick_expr.as(:nick_expr)
    }

    rule (:nick_expr) {
      (str("!") >> (nick_expr | nick_selector | nick_atom_loose).as(:nick)).as(:negated_nick) |
        nick_selector.as(:nick)
    }
    rule(:nick_selector) {
      (str("@") >> match["@:"].repeat >> nick_atom_loose) |
      (str(":") >> match["@:"].repeat >> nick_atom_loose) |
      nick_atom_strict
    }
    rule(:nick_atom_loose) {
      nick_self | nick_any | nick_name_loose
    }
    rule(:nick_atom_strict) {
      nick_self | nick_any | nick_name_strict
    }
    rule(:nick_self) { str(".") }
    rule(:nick_any)  { str("*") }
    rule(:nick_name_strict) {
      ( match["0-9"].repeat >>
        nick_alpha_char >>
        nick_char.repeat )
    }
    rule(:nick_name_loose) { nick_char.repeat(1) }
    rule(:nick_char) {
      match['0-9a-zA-Z_`\[\]{}\\^-']
    }
    rule(:nick_alpha_char) {
      match['a-zA-Z_`\[\]{}\\|^-']
    }
  end
end
