module Sqlop
  class TVViewCount
    def self.increment(game)
      table = game['sql_table'] or raise "No sql_table field in game"
      sql_db_handle.do("UPDATE #{table} SET ntv = ntv + 1 " +
        "WHERE id = ?", game['id'])
    end
  end
end
