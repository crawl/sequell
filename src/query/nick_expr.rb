require 'query/nick'
require 'query/expr'
require 'sql/field_predicate'

module Query
  class NickExpr < Expr
    def self.nick(nick)
      return nick if nick.is_a?(self)
      self.new(nick)
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

    def self.expr(nick, inverted)
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
        QueryStruct.or_clause(inverted,
          *aliases.map { |a| single_nick_predicate(a, inverted) })
      end
    end

    def self.single_nick_predicate(nick, inverted)
      Sql::FieldPredicate.predicate(nick, inverted ? '!=' : '=', 'name')
    end

    def initialize(nick)
      super(:'=', Sql::Field.field('name'), nick)
    end
  end
end
