require 'query/nick_expr'

module Query
  class QueryNodeTranslator
    def self.translate(node)
      if node.field_value_equality? && node.left === 'name'
        return nil if node.right.value == '*'
        ::Query::NickExpr.with_default_nick(@nick) {
          return ::Query::NickExpr.expr(node.right.value,
            !node.operator.equal?)
        }
      end
      node
    end
  end
end
