module Sqlop
  class TVViewCount
    def self.increment(game)
      table = game['sql_table'] or raise "No sql_table field in game"
      SQLConnection.with_connection do |c|
        c.do("UPDATE #{table} SET ntv = coalesce(ntv, 0) + 1 " +
             "WHERE id = ?", game['id'])
      end
    end
  end
end
