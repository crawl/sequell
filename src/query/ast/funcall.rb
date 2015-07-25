module Query
  module AST
    class Funcall < Term
      attr_reader :name, :fn

      def initialize(name, *arguments)
        @name = name
        @fn = SQL_CONFIG.functions.function(name)
        unless @fn
          @fn = SQL_CONFIG.aggregate_functions.function(name) or
            raise "Unknown function: #{name}"
          @aggregate = true
        end
        @arguments = arguments
      end

      def initialize_copy(o)
        super
        @name = @name.dup
        @arguments = @arguments.map(&:dup)
      end

      def display_value(raw_value, format=nil)
        self.type.display_value(raw_value, format || @fn.display_format)
      end

      def aggregate?
        @aggregate
      end

      def typecheck!
        @fn.typecheck!(arguments)
      rescue Sql::TypeError => e
        raise Sql::TypeError.new("#{self}: #{e}")
      end

      def convert_types!
        typecheck!
        self.arguments = @fn.coerce_argument_types(self.arguments)
      end

      def kind
        :funcall
      end

      def type
        @fn.return_type(self.arguments)
      end

      def to_s
        "#{@name}(" + arguments.map(&:to_s).join(',') + ")"
      end

      def to_sql
        expr = @fn.expr.gsub(/%s/) { |m|
          self.first.to_sql
        }.gsub(/:(\d+)\b/) { |m|
          arguments[$1.to_i - 1].to_sql
        }
        if self.alias
          "#{expr} AS #{self.alias}"
        else
          expr
        end
      end

      def sql_values
        argrefs = []
        @fn.expr.gsub(/%s/) { |m|
          argrefs << self.first
          ''
        }.gsub(/:(\d+)\b/) { |m|
          argrefs << arguments[$1.to_i - 1]
          ''
        }
        argrefs.map(&:sql_values).flatten
      end
    end
  end
end
