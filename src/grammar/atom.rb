require 'parslet'

module Grammar
  class Atom < Parslet::Parser
    rule(:identifier) {
      match["a-zA-Z_."] >> match["a-zA-Z0-9_."].repeat
    }

    rule(:quoted_string) {
      single_quoted_string | double_quoted_string
    }

    rule(:single_quoted_string) {
      str("'") >> (str('\\') >> str('\\').as(:char) |
                   str('\\') >> str("'").as(:char) |
                   match["^'"].as(:char)).repeat.as(:string) >> str("'")
    }

    rule(:double_quoted_string) {
      str('"') >> (str('\\') >> str('\\').as(:char) |
                   str('\\') >> str('"').as(:char) |
                   match['^"'].as(:char)).repeat.as(:string) >> str('"')
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
      float | integer
    }

    rule(:sign) {
      match["+-"]
    }

    rule(:digits) {
      match["0-9"].repeat(1)
    }
  end
end
