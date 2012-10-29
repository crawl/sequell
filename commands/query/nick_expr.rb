require 'query/nick'
require 'sql/field_predicate'

module Query
  class NickExpr
    def self.expr(nick, inverted)
      if nick =~ /^!/
        nick = nick.sub(/^!/, '')
        inverted = !inverted
      end
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
  end
end
