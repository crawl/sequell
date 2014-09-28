require 'query/nick'
require 'query/ast/expr'
require 'set'

module Query
  class NickExpr < AST::Expr
    PENDING_EXPANSIONS = Set.new
    def self.nick(nick)
      return nick if nick.is_a?(self)
      self.new(nick.to_s)
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

      mapping_predicate(Query::Nick.mapping(nick), inverted)
    end

    def self.mapping_predicate(mapping, inverted)
      recursive_expansion_protect(mapping) {
        condition = nil
        if mapping.has_condition?
          condition = Query::ListgameParser.fragment(
            mapping.listgame_conditions)
        end
        nick_predicate = self.nick_predicate(mapping, inverted)
        return nick_predicate unless condition
        Query::AST::Expr.new(inverted ? :or : :and,
          nick_predicate,
          inverted ? Query::AST::Expr.new(:not, condition) : condition)
      }
    end

    def self.nick_predicate(mapping, inverted)
      if mapping.size == 1
        self.single_nick_predicate(mapping.primary, inverted)
      else
        Query::AST::Expr.new(inverted ? :and : :or,
          *mapping.expansions.map { |a| single_nick_predicate(a, inverted) })
      end
    end

    def self.single_nick_predicate(nick, inverted)
      Query::AST::Expr.new(inverted ? '!=' : '=',
        Sql::Field.field('name'), nick)
    end

    attr_reader :nick

    def initialize(nick, negated=false)
      nick = Query::AST::Value.value(nick.to_s)
      super(negated ? :'!=' : :'=', Sql::Field.field('name'), nick)
      @nick = nick
      @negated = negated
    end

    def dup
      duplicate = self.class.new(@nick, @negated)
      duplicate.field = self.field.dup
      duplicate
    end

    def to_query_string(wrapping_parens=nil)
      return nil if @nick.value == '*'
      @nick.value
    end

  private

    def self.recursive_expansion_protect(mapping)
      if PENDING_EXPANSIONS.include?(mapping.nick)
        raise "recursive nick expansion in #{mapping}"
      end
      PENDING_EXPANSIONS.add(mapping.nick)
      begin
        yield
      ensure
        PENDING_EXPANSIONS.delete(mapping.nick)
      end
    end
  end
end
