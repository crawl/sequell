require 'parslet'

module Grammar
  class Atom < Parslet::Parser
    rule(:identifier) {
      match["a-zA-Z_."] >> match["a-zA-Z0-9_."].repeat
    }

    rule(:simple_value) {
      match["^ "]
    }

    rule(:integer) {
      sign.maybe >> digits
    }

    rule(:sign) {
      match["+-"]
    }

    rule(:digits) {
      match["0-9"].repeat(1)
    }
  end
end
