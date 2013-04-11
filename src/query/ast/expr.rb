require 'query/operators'
require 'query/ast/term'
require 'query/ast/value'
require 'sql/field'

module Query
  module AST
    class Expr < Term
      def self.and(*arguments)
        self.new(Query::Operator.op(:and), *arguments)
      end

      def self.or(*arguments)
        self.new(Query::Operator.op(:or), *arguments)
      end

      def self.field_predicate(op, field, value)
        self.new(op, Sql::Field.field(field), value)
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
        @original = @arguments.map { |a| a.dup }
      end

      def operator=(op)
        @operator = Query::Operator.op(op)
      end

      def dup
        self.class.new(operator, *arguments.map { |a| a.dup }).with_flags(flags)
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
        Expr.new(operator.negate,
          *arguments.map { |arg|
            arg.negatable? ? arg.negate : arg
          })
      end

      def negatable?
        self.operator.negatable?
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
          Expr.new(merge_op, self.dup, other.dup)
        else
          merged = self.dup
          merged.arguments += other.dup.arguments
          merged
        end
      end

      def convert_types!
        arg_type = self.operator.argtype(arguments)
        self.arguments = self.arguments.map { |arg|
          #debug{"Converting #{arg} (#{arg.class}) to #{arg_type}"}
          arg.convert_to_type(arg_type)
        }.compact
        self
      rescue Sql::TypeError => e
        raise Sql::TypeError.new(e.message + " in '#{self}'")
      end

      def << (term)
        self.arguments << term
        self
      end

      def to_s
        return '' if self.arity == 0
        self.to_query_string(false)
      end

      def to_sql
        return '' if arity == 0
        if self.operator.unary?
          "(#{operator.to_sql} (#{self.arguments.first.to_sql}))"
        elsif self.in_clause_transformable?
          self.in_clause_sql
        else
          wrap_if(arity > 1, '(', ')') {
            arguments.map { |a| a.to_sql }.join(operator.to_sql)
          }
        end
      end

      def in_clause_transformable?
        return unless self.first && self.first.field_value_predicate?

        first_field = self.first.field
        first_op = self.first.operator
        return unless first_op.equality?

        wanted_op = first_op.equal? ? :or : :and
        self.operator == wanted_op &&
          self.arguments.all? { |arg|
            arg.field_value_predicate? && arg.field == first_field &&
            arg.operator == first_op
          }
      end

      def in_clause_sql
        field = self.first.field
        values = self.arguments.map { |x| '?' }.join(', ')
        op = self.first.operator.equal? ? 'IN' : 'NOT IN'
        "#{field.to_sql} #{op} (#{values})"
      end

      def to_in_clause_query_string
        field = self.first.field
        op = self.first.operator
        value = self.arguments.map(&:value).join('|')
        "#{field}#{op}#{value}"
      end

      def child_query(child, parens=true)
        wrap_if(child.sql_expr? && !sql_expr?, '${', '}') {
          child.to_query_string(parens)
        }
      end

      def to_query_string(wrapping_parens=true)
        if self.operator.unary?
          "#{operator.display_string}#{child_query(self.first)}"
        else
          if self.in_clause_transformable?
            return self.to_in_clause_query_string
          end

          wrap_with_parens = wrapping_parens && self.arity > 1
          text = arguments.map { |a|
            child_query(a, self.operator > a.operator)
          }.compact.join(operator.display_string)
          text = "(#{text})" if wrap_with_parens
          text
        end
      end

      def sql_values
        values = []
        ASTWalker.map_values(self) { |value|
          values << value.value unless value.null?
          value
        }
        values
      end
    end
  end
end
