require 'query/ast/ast_walker'
require 'query/nick_expr'
require 'query/text_template'
require 'query/query_template_properties'
require 'command_context'

module Query
  module AST
    class QueryAST
      attr_accessor :context, :context_name, :head, :tail, :filter
      attr_accessor :extra, :summarise, :options, :sorts
      attr_accessor :game_number, :nick, :default_nick, :game
      attr_accessor :group_order, :keys

      def initialize(context_name, head, tail, filter)
        @game = GameContext.game
        @context_name = context_name.to_s
        @context = Sql::QueryContext.named(@context_name)
        @head = head || Expr.and()
        @original_head = @head.dup
        @tail = tail
        @original_tail = @tail && @tail.dup

        @filter = filter
        @options = []
        @opt_map = { }
        @sorts = []
        @keys = Query::AST::KeyedOptionList.new

        @nick = ASTWalker.find(@head) { |node|
          node.nick.value if node.is_a?(NickExpr)
        }

        unless @nick
          @nick = '.'
          @head << ::Query::NickExpr.nick('.')
        end
      end

      def resolve_nick(nick)
        nick == '.' ? default_nick : nick
      end

      # The first nick in the query, with . expanded to point at the
      # user requesting.
      def target_nick
        resolve_nick(@nick)
      end

      # The first real nick in the query.
      def real_nick
        @real_nick ||=
          real_nick_in(@original_head) ||
          real_nick_in(@original_tail) || target_nick
      end

      def real_nick_in(tree)
        return nil unless tree
        ASTWalker.find(tree) { |node|
          if node.is_a?(NickExpr) && node.nick.value != '*'
            resolve_nick(node.nick.value)
          elsif node.kind == :keyword && node.value =~ /^[@:]/
            resolve_nick(node.value.gsub(/^[@:]+/, ''))
          end
        }
      end

      def key_value(key)
        self.keys[key]
      end

      def result_prefix_title
        key_value(:title)
      end

      def template_properties
        ::Query::QueryTemplateProperties.properties(self)
      end

      def default_join
        @default_join ||= self.key_value(:join) || CommandContext.default_join
      end

      def stub_message_format
        @stub_message_format ||= self.key_value(:stub)
      end

      def stub_message_template
        @template ||=
          stub_message_format && Tpl::Template.template(stub_message_format)
      end

      def stub_message(nick)
        stub_template = self.stub_message_template
        return Tpl::Template.eval_string(stub_template, self.template_properties) if stub_template

        entities = self.context.entity_name + 's'
        puts "No #{entities} for #{self.description(nick)}."
      end

      def needs_group_order?
        !self.group_order && self.summarise
      end

      def default_group_order
        (extra && extra.default_group_order) ||
          (summarise && summarise.default_group_order)
      end

      def head_desc(suppress_meta=true)
        stripped_ast_desc(@original_head, true, suppress_meta)
      end

      def tail_desc(suppress_meta=true, slash_prefix=true)
        return '' unless @original_tail
        tail_text = stripped_ast_desc(@original_tail, false, suppress_meta)
        slash_prefix ? "/ " + tail_text : tail_text
      end

      def stripped_ast_desc(ast, suppress_nick=true, suppress_meta=true)
        ast.without { |node|
          (suppress_nick && node.is_a?(Query::NickExpr)) ||
            (suppress_meta && node.meta?)
        }.to_s.strip
      end

      def description(default_nick=self.default_nick,
                      options={})
        texts = []
        texts << self.context_name if options[:context]
        texts << (@nick == '.' ? default_nick : @nick).dup
        desc = self.head_desc(!options[:meta])
        if !desc.empty?
          texts << (!options[:no_parens] ? "(#{desc})" : desc)
        end
        texts << tail_desc(!options[:meta]) if options[:tail]
        texts.join(' ').strip
      end

      def add_option(option)
        @options << option
        @opt_map[option.name.to_sym] = option
      end

      def option(name)
        @opt_map[name.to_sym]
      end

      def random?
        option(:random)
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
        self.summarise = block.call(self.summarise) if self.summarise
        if self.sorts
          self.sorts = self.sorts.map { |sort|
            block.call(sort)
          }.compact
        end
        self.group_order = block.call(self.group_order) if self.group_order
        self.extra = block.call(self.extra) if self.extra
        self.head = block.call(self.head)
        @full_tail = block.call(@full_tail) if @full_tail
        self.tail = block.call(self.tail) if self.tail
        self
      end

      def transform_nodes!(&block)
        self.map_nodes_as!(:map_nodes, &block)
      end

      def each_node(&block)
        self.summarise.each_node(&block) if self.summarise
        if self.sorts
          self.sorts.each { |sort|
            sort.each_node(&block)
          }
        end
        self.group_order.each_node(&block) if self.group_order
        self.extra.each_node(&block) if self.extra
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
