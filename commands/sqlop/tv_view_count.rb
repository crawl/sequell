module Sqlop
  class TVViewCount
    def self.increment(game)
      table = g['sql_table'] or raise "No sql_table field in game"
      sql_db_handle.do("UPDATE #{table} SET ntv = ntv + 1 " +
        "WHERE id = ?", g['id'])
    end
  end
end
