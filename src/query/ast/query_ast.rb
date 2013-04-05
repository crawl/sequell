module Query
  module AST
    class QueryAST
      attr_accessor :context, :head, :tail, :filter
      attr_accessor :extra, :summarize, :options
      attr_accessor :game_number

      def initialize(context, head, tail, filter)
        @context = context
        @head = head || Expr.and()
        @tail = tail
        @filter = filter
      end

      def compound_query?
        @tail
      end

      def with_context(&block)
        Sql::QueryContext.named(self.context).with(&block)
      end

      def full_tail
        @full_tail ||= @tail && @tail.merge(@head)
      end

      def to_s
        tail_s = @tail ? " / #{@tail}" : ""
        "#{@context} #{@head}#{tail_s} #{@filter}"
      end
    end
  end
end
