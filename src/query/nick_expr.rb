require 'query/nick'
require 'query/ast/expr'

module Query
  class NickExpr < AST::Expr
    def self.nick(nick)
      return nick if nick.is_a?(self)
      self.new(nick)
    end

    def self.negated(nick)
      self.new(nick, true)
    end

    def self.with_default_nick(nick)
      old_default_nick = @default_nick
      begin
        @default_nick = nick
        yield
      ensure
        @default_nick = old_default_nick
      end
    end

    def self.default_nick
      @default_nick
    end

    def self.expr(nick, inverted=false)
      if nick =~ /^!/
        nick = nick.sub(/^!/, '')
        inverted = !inverted
      end

      nick = nick.sub(/^@+/, '')
      nick = self.default_nick || nick if nick == '.'

      aliases = Query::Nick.aliases(nick)
      if aliases.size == 1
        self.single_nick_predicate(aliases[0], inverted)
      else
        Query::AST::Expr.new(inverted ? :and : :or,
          *aliases.map { |a| single_nick_predicate(a, inverted) })
      end
    end

    def self.single_nick_predicate(nick, inverted)
      Query::AST::Expr.new(inverted ? '!=' : '=',
        Sql::Field.field('name'), nick)
    end

    attr_reader :nick

    def initialize(nick, negated=false)
      nick = Query::AST::Value.value(nick)
      super(negated ? :'!=' : :'=', Sql::Field.field('name'), nick)
      @nick = nick
      @negated = negated
    end

    def dup
      self.class.new(@nick, @negated)
    end

    def to_query_string(wrapping_parens=nil)
      return nil if @nick.value == '*'
      @nick
    end
  end
end
