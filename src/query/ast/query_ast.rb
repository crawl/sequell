require 'query/ast/ast_walker'
require 'query/nick_expr'

module Query
  module AST
    class QueryAST
      attr_accessor :context, :context_name, :head, :tail, :filter
      attr_accessor :extra, :summarise, :options, :sorts
      attr_accessor :game_number, :nick, :game
      attr_accessor :group_order

      def initialize(context_name, head, tail, filter)
        @game = GameContext.game
        @context_name = context_name.to_s
        @context = Sql::QueryContext.named(@context_name)
        @head = head || Expr.and()
        @tail = tail

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

        @desc = @head.without { |node|
          node.is_a?(Query::NickExpr) || node.meta?
        }.to_s.strip
      end

      def description(default_nick=Query::NickExpr.default_nick)
        text = (@nick == '.' ? default_nick : @nick).dup
        if !@desc.empty?
          text << " (#{@desc})"
        end
        text
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
        summarise || (extra && extra.aggregate?) || self.tail
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
        @full_tail = block.call(@full_tail) if @full_tail
        self.tail = block.call(self.tail) if self.tail
        self
      end

      def transform_nodes!(&block)
        self.map_nodes_as!(:map_nodes, &block)
      end

      def each_node(&block)
        self.head.each_node(&block)
        (self.full_tail || self.tail).each_node(&block) if self.tail
        self
      end

      def map_nodes_as!(mapper, *args, &block)
        self.transform! { |tree|
          ASTWalker.send(mapper, tree, *args, &block)
        }
      end

      def with_context(&block)
        self.context.with(&block)
      end

      def bind_tail!
        @full_tail = @tail && @tail.merge(@head)
      end

      def full_tail
        @full_tail
      end

      def to_s
        pieces = [context_name]
        pieces << @nick if @nick
        pieces << head.to_query_string(false)
        pieces << @summarise.to_s if summary?
        pieces << "/" << @tail.to_query_string(false) if @tail
        pieces << "?:" << @filter.to_s if @filter
        pieces.select { |x| !x.empty? }.join(' ')
      end
    end
  end
end
