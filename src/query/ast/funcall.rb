module Query
  module AST
    class Funcall < Term
      attr_reader :name

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

      def aggregate?
        @aggregate
      end

      def kind
        :funcall
      end

      def type
        @fn.return_type(self.first)
      end

      def to_s
        "#{@name}(" + arguments.map(&:to_s).join(',') + ")"
      end
    end
  end
end
