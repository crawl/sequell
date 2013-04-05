require 'query/ast/ast_walker'

module Query
  module AST
    class QueryAST
      attr_accessor :context, :head, :tail, :filter
      attr_accessor :extra, :summarise, :options, :sorts
      attr_accessor :game_number

      def initialize(context, head, tail, filter)
        @context = context
        @head = head || Expr.and()
        @tail = tail
        @filter = filter
        @summarise = []
        @options = []
        @sorts = []
      end

      def summary?
        !@summarise.empty?
      end

      def has_sorts?
        !@sorts.empty?
      end

      def reverse_sorts!
        @sorts = @sorts.map { |sort| sort.reverse }
      end

      def needs_sort?
        !summary? && !compound_query?
      end

      def primary_sort
        @sorts.first
      end

      def compound_query?
        @tail
      end

      def transform!(&block)
        self.head = block.call(self.head)
        self.tail = block.call(self.tail) if self.tail
        self
      end

      def transform_nodes!(&block)
        self.map_nodes_as!(:map_nodes, &block)
      end

      def map_nodes_as!(mapper, *args, &block)
        self.transform! { |tree|
          ASTWalker.send(mapper, tree, *args, &block)
        }
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
