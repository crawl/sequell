require 'query/operators'
require 'query/ast/term'

module Query
  module AST
    class Expr < Term
      def self.and(*arguments)
        self.new(Query::Operator.op(:and), *arguments)
      end

      attr_reader :operator, :arguments

      def initialize(operator, *arguments)
        @operator = Query::Operator.op(operator)
        @arguments = arguments.compact.map { |arg|
          if !arg.respond_to?(:kind)
            Value.new(arg)
          else
            arg
          end
        }
      end

      def negate
        Expr.new(operator.negate, arguments.map(&:negate))
      end

      def kind
        :expr
      end

      def typecheck!
        operator.typecheck!(args)
      end

      def type
        operator.result_type(args)
      end

      def merge(other, merge_op=:and)
        raise "Cannot merge #{self} with #{other}" unless other.is_a?(Expr)
        if self.operator != other.operator || self.operator.arity != 0
          Expr.new(merge_op, self, other)
        else
          merged = self.dup
          merged.arguments += other.arguments
          merged
        end
      end

      def << (term)
        self.arguments << term
        self
      end

      def to_s
        "(#{operator.to_s} " + arguments.map(&:to_s).join(' ') + ")"
      end

      def to_query_string
        if self.operator.unary?
          "#{operator.display_string}#{self.arguments.first.to_query_string}"
        else
          self.arguments.map(&:to_query_string).join(
            "#{operator.display_string}")
        end
      end
    end
  end
end
