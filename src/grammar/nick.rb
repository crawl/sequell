module Grammar
  class Nick < Parslet::Parser
    root(:nick_expr)

    rule(:negated) { str("!").as(:negated) }

    rule (:nick_expr) {
      (negated >> (nick_selector | nick_atom_loose)).as(:negated) |
        nick_selector
    }
    rule(:nick_selector) {
      (str("@") >> nick_atom_loose).as(:nick_alias) | nick_atom_strict
    }
    rule(:nick_atom_loose) {
      nick_self | nick_any | nick_name_loose
    }
    rule(:nick_atom_strict) {
      nick_self | nick_any | nick_name_strict
    }
    rule(:nick_self) { str(".").as(:nick_self) }
    rule(:nick_any)  { str("*").as(:nick_any) }
    rule(:nick_name_strict) {
      ( match["0-9"].repeat >>
        nick_alpha_char >>
        nick_char.repeat).as(:nick)
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
