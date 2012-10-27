module Sqlop
  class TVViewCount
    def self.increment(game)
      table = g['milestone'] ? 'milestone' : 'logrecord'
      sql_db_handle.do("UPDATE #{table} SET ntv = ntv + 1 " +
        "WHERE id = ?", g['id'])
    end
  end
end
