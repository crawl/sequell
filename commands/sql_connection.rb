require 'dbi'

DBNAME = ENV['HENZELL_DBNAME'] || 'henzell'
DBUSER = ENV['HENZELL_DBUSER'] || 'henzell'
DBPASS = ENV['HENZELL_DBPASS'] || ''

class DBHandle
  def initialize(db)
    @db = db
  end

  def get_first_value(query, *binds)
    @db.prepare(query) do |sth|
      sth.execute(*binds)
      row = sth.fetch
      return row[0]
    end
    nil
  end

  def execute(query, *binds)
    @db.prepare(query) do |sth|
      sth.execute(*binds)
      while row = sth.fetch
        yield row
      end
    end
  end

  def do(query, *binds)
    @db.do(query, *binds)
  end
end

class SQLConnection
  @@db_handle = nil

  def self.sql_connection
    @@db_handle = self.connect
  end

  def self.connect
    DBHandle.new(DBI.connect('DBI:Pg:' + DBNAME, DBUSER, DBPASS))
  end
end

def sql_db_handle
  SQLConnection.sql_connection
end
