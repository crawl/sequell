# encoding: UTF-8
module Grammar
  class Nick < Parslet::Parser
    root(:nick_root)

    rule(:nick_root) {
      nick_expr.as(:nick_expr)
    }

    rule (:nick_expr) {
      (str("!") >> (nick_expr | nick_selector).as(:nick)).as(:negated_nick) |
        nick_selector.as(:nick)
    }
    rule(:nick_selector) {
      (match["@:"].repeat >> nick_atom_loose)
    }
    rule(:nick_atom_loose) {
      nick_self | nick_any | nick_name_loose
    }
    rule(:nick_atom_strict) {
      nick_self | nick_any | nick_name_strict
    }

    rule(:nick_self) { str(".") }
    rule(:nick_any)  { str("*") }
    rule(:nick_name_loose) {
      nick_char.repeat(1)
    }
    rule(:nick_name_strict) {
      nick_char_safe.repeat(1)
    }
    rule(:nick_char) {
      nick_char_safe | match['|']
    }
    rule(:nick_char_safe) {
      match['0-9a-zA-Z_`\[\]{}\\^[^\x00-\x7f]\\\\-']
    }
    rule(:nick_alpha_char) {
      match['\p{Alpha}a-zA-Z_`\[\]{}\\|^-']
    }
  end
end
