require 'parslet'
require 'ast/sort_expr'

module Grammar
  class QueryTransform < Parslet::Transform
    rule(min: simple(:field_expr)) {
      AST::SortExpr.sort(AST::OrderedExpr.min(field_expr))
    }

    rule(max: simple(:field_expr)) {
      AST::SortExpr.sort(AST::OrderedExpr.max(field_expr))
    }
  end
end
