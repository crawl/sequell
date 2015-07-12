require 'parslet'

# Operators: + - / % * ^ = != =~ ~~ | & && || ( ), function call.
# Precedence: && ||, (in)equality, + -, bitwise math, * / %, **,
module Grammar
  class SqlExpr < Parslet::Parser
    root(:sql_expr)

    rule(:sql_expr) {
      escaped_expr | window_function_expr
    }

    rule(:window_function_expr) {
      (function_call >> space? >> str("::") >> space? >> partition_expr).as(:window_funcall)
    }

    rule(:partition_expr) {
      (str("partition(") >> partition_fields.as(:partition_fields) >>
       (space? >> str(",") >> space? >> order_term).maybe.as(:partition_order) >>
       space? >> str(")")).as(:partition)
    }

    rule(:order_term) {
      QueryTerm.new.order_term
    }

    rule(:partition_fields) {
      expr >> ( space? >> str(",") >> space? >> (order_term.absent? >> expr) ).repeat
    }

    rule(:escaped_expr) {
      str("${") >> space? >> expr.as(:sql_expr) >> space? >> str("}") |
      str("$") >> space? >> expr.as(:sql_expr) >> space? >>
      (any.absent? | str("$"))
    }

    rule(:expr) {
      (or_expr.as(:expr) >>
        (space? >> str("||") >> space? >>
          or_expr.as(:expr)).repeat(1)).as(:or) |
      or_expr
    }

    rule(:or_expr) {
      (neg_expr.as(:expr) >> (space >> neg_expr.as(:expr)).repeat(1)).as(:and) |
      neg_expr
    }

    rule(:neg_expr) {
      str('!') >> space? >> cmp_expr.as(:negated) | cmp_expr
    }

    rule(:cmp_expr) {
      eqterm.as(:left) >> space? >>
      eqop.as(:op) >> space? >> eqterm.as(:right) |
      eqterm
    }

    rule(:eqop) {
      ::Query::Grammar.operators_by_length.map { |x| str(x) }.reduce(&:|)
    }

    rule(:eqterm) {
      bitwiseterm
      # bitwiseterm.as(:left) >> (space? >> bitwise_op >> space? >>
      #   eqterm).repeat(1).as(:right) |
      # bitwiseterm
    }

    rule(:bitwiseterm) {
      addterm.as(:left) >> (space? >> additive_op >> space? >>
        addterm.as(:right)).repeat(1).as(:right_partial) |
      addterm
    }

    rule(:addterm) {
      multerm.as(:left) >> (space? >> multiplicative_op >> space? >>
        multerm.as(:right)).repeat(1).as(:right_partial) |
      multerm
    }

    rule(:multerm) {
      expterm.as(:left) >> (space? >> exp_op >> space? >>
        expterm.as(:right)).repeat(1).as(:right_partial) |
      expterm
    }

    rule(:expterm) {
      str("-") >> simple_expr.as(:arithmetic_negated) |
      str("+") >> simple_expr.as(:plus) |
      (str("~").as(:op) >> expterm.as(:expr)).as(:complement) |
      simple_expr
    }

    rule(:subquery) {
      QueryBody.new.subquery
    }

    rule(:simple_expr) {
      parenthesized_expr | function_call | subquery | atom
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
      function_arguments.maybe.as(:arguments) >> space? >>
      str(")")
    }

    rule(:function_name) {
      Atom.new.identifier.as(:function_name)
    }

    rule(:function_arguments) {
      function_arg >> (space? >> str(",") >> space? >> function_arg).repeat
    }

    rule(:function_arg) {
      expr.as(:function_argument)
    }

    rule(:space) {
      match('\s').repeat(1)
    }
    rule(:space?) { space.maybe }
  end
end
