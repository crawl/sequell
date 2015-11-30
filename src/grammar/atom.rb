# encoding: UTF-8

require 'parslet'

module Grammar
  class Atom < Parslet::Parser
    rule(:identifier) {
      match["a-zA-Z_[^\x00-\x7f]".force_encoding('UTF-8')] >>
      match["a-zA-Z0-9_.[^\x00-\x7f]".force_encoding('UTF-8')].repeat
    }

    rule(:quoted_string) {
      single_quoted_string | double_quoted_string
    }

    def quoted_body(quote)
      (str('\\') >> str('\\').as(:char) |
        str('\\') >> str(quote).as(:char) |
        match["^#{quote}"].as(:char))
    end

    def escaped_quoted_body(quote)
      (str('\\') >> str('\\')).as(:char) |
      (str('\\') >> str(quote)).as(:char) |
      match["^#{quote}"].as(:char)
    end

    rule(:wrapped_single_quoted_string) {
      (str("'").as(:leftquot) >> escaped_quoted_body("'").repeat >> str("'").as(:rightquot)).as(:string)
    }

    rule(:single_quoted_string) {
      str("'") >> quoted_body("'").repeat.as(:string) >> str("'")
    }

    rule(:double_quoted_string) {
      str('"') >> quoted_body('"').repeat.as(:string) >> str('"')
    }

    rule(:safe_value) {
      match('\S')
    }

    rule(:boolean) {
      str("false").as(:false) | str("true").as(:true) |
      str("f").as(:false) | str("t").as(:true) |
      str("n").as(:false) | str("y").as(:true)
    }

    rule(:integer) {
      sign.maybe >> digits
    }

    rule(:float) {
      sign.maybe >> (integer >> str(".") >> integer.maybe |
        str(".") >> integer)
    }

    rule(:number) {
      float.as(:float) | integer.as(:integer)
    }

    rule(:sign) {
      match["+-"]
    }

    rule(:digits) {
      match["0-9"].repeat(1)
    }
  end
end
