require 'query/operators'
require 'query/ast/term'
require 'sql/field'

module Query
  module AST
    class Expr < Term
      def self.and(*arguments)
        self.new(Query::Operator.op(:and), *arguments)
      end

      def self.field_predicate(op, field, value)
        self.new(op, Sql::Field.field(field), value)
      end

      attr_reader :operator, :arguments
      alias :args :arguments

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

      def operator=(op)
        @operator = Query::Operator.op(op)
      end

      def dup
        self.class.new(operator, *arguments.map { |a| a.dup })
      end

      def fields
        self.arguments.select { |arg|
          arg.kind == :field
        }
      end

      def resolved?
        self.fields.all? { |field| field.qualified? }
      end

      def each_predicate(&block)
        arguments.each { |arg|
          arg.each_predicate(&block) if arg.kind == :expr
          block.call(arg) if arg.type.boolean?
        }
        block.call(self) if self.boolean?
      end

      def each_field(&block)
        ASTWalker.each_field(self, &block)
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

      def to_sql(tables, ctx)
        if self.operator.unary?
          "#{operator.to_sql} #{self.arguments.first.to_sql(tables, ctx)}"
        else
          self.arguments.map { |a| a.to_sql(tables, ctx) }.join(operator.to_sql)
        end
      end

      def to_query_string
        if self.operator.unary?
          "#{operator.display_string}#{self.arguments.first.to_query_string}"
        else
          self.arguments.map(&:to_query_string).join(
            "#{operator.display_string}")
        end
      end

      def sql_values
        values = []
        ASTWalker.map_values(self) { |value|
          values << value.value
          value
        }
        values
      end
    end
  end
end
