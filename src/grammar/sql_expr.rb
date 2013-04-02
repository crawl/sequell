require 'parslet'

# Operators: + - / % * ^ = != =~ ~~ | & && || ( ), function call.
# Precedence: && ||, (in)equality, + -, bitwise math, * / %, **,
module Grammar
  class SqlExpr < Parslet::Parser
    root(:escaped_expr)

    rule(:escaped_expr) {
      str("${") >> space? >> expr.as(:sql_expr) >> space? >> str("}")
    }

    rule(:expr) {
      (or_expr.as(:left) >>
        (space? >> str("||") >> space? >> or_expr.as(:right)).repeat(1)).as(:or) |
      or_expr
    }

    rule(:or_expr) {
      (neg_expr.as(:left) >> (space >> neg_expr.as(:right)).repeat(1)).as(:and) |
      neg_expr
    }

    rule(:neg_expr) {
      str('!') >> space? >> cmp_expr.as(:negated) | cmp_expr
    }

    rule(:cmp_expr) {
      eqterm.as(:left) >> space? >> eqop.as(:op) >> space? >> eqterm.as(:right) |
      eqterm
    }

    rule(:eqop) {
      ::Query::Grammar.operators_by_length.map { |x| str(x) }.reduce(&:|)
    }

    rule(:eqterm) {
      bitwiseterm.as(:left) >> space? >> bitwise_op >> space? >>
      bitwiseterm.as(:right) |
      bitwiseterm
    }

    rule(:bitwiseterm) {
      addterm.as(:left) >> space? >> additive_op >> space? >>
      addterm.as(:right) |
      addterm
    }

    rule(:addterm) {
      multerm.as(:left) >> space? >> multiplicative_op >> space? >>
      multerm.as(:right) |
      multerm
    }

    rule(:multerm) {
      expterm.as(:left) >> space? >> exp_op >> space? >> expterm.as(:right) |
      expterm
    }

    rule(:expterm) {
      str("-") >> simple_expr.as(:negated) |
      str("+") >> simple_expr.as(:plus) |
      (str("~").as(:op) >> simple_expr.as(:expr)).as(:complement) |
      simple_expr
    }

    rule(:simple_expr) {
      parenthesized_expr | function_call | atom
    }

    rule(:atom) {
      field | string | number | boolean
    }

    rule(:field) {
      QueryTerm.new.field
    }

    rule(:string) {
      Atom.new.quoted_string
    }

    rule(:number) {
      Atom.new.number.as(:number)
    }

    rule(:boolean) {
      (str("false") | str("true")).as(:boolean)
    }

    rule(:exp_op) {
      str("**").as(:op)
    }

    rule(:bitwise_op) {
      match['|&^'].as(:op)
    }

    rule(:multiplicative_op) {
      match["*/%"].as(:op)
    }

    rule(:additive_op) {
      match["+-"].as(:op)
    }

    rule(:parenthesized_expr) {
      str("(") >> space? >> expr.as(:parentheses) >> space? >> str(")")
    }

    rule(:function_call) {
      function_name >> space? >> str("(") >>
      function_args >> space? >>
      str(")")
    }

    rule(:function_name) {
      Atom.new.identifier.as(:fname)
    }

    rule(:function_args) {
      function_arg >> (space? >> str(",") >> space? >> function_arg).repeat
    }

    rule(:function_arg) {
      expr.as(:arg)
    }

    rule(:space) {
      match('\s').repeat(1)
    }
    rule(:space?) { space.maybe }
  end
end
