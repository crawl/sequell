require 'query/ast/ast_walker'

module Query
  module AST
    class QueryAST
      attr_accessor :context, :context_name, :head, :tail, :filter
      attr_accessor :extra, :summarise, :options, :sorts
      attr_accessor :game_number, :nick, :game

      attr_reader :head_str, :tail_str

      def initialize(context_name, head, tail, filter)
        @game = GameContext.game
        @context_name = context_name.to_s
        @context = Sql::QueryContext.named(@context_name)
        @head = head || Expr.and()
        @tail = tail

        @head_str = @head.to_query_string(false)
        @tail_str = @tail && @tail.to_query_string(false)

        @filter = filter
        @options = []
        @opt_map = { }
        @sorts = []

        @nick = ASTWalker.find(@head) { |node|
          node.nick.value if node.is_a?(NickExpr)
        }

        unless @nick
          @nick = '.'
          @head << ::Query::NickExpr.nick('.')
        end
      end

      def add_option(option)
        @options << option
        @opt_map[option.name.to_sym] = option
      end

      def option(name)
        @opt_map[name.to_sym]
      end

      def head
        @head ||= Expr.and()
      end

      def summary?
        summarise || (extra && extra.aggregate?)
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
        self.context.with(&block)
      end

      def full_tail
        @full_tail ||= @tail && @tail.merge(@head)
      end

      def to_s
        pieces = [context_name]
        pieces << @nick if @nick
        pieces << head.to_query_string(false)
        pieces << @summarise.to_s if summary?
        pieces << "/" << @tail.to_query_string(false) if @tail
        pieces << @filter.to_s if @filter
        pieces.select { |x| !x.empty? }.join(' ')
      end
    end
  end
end
