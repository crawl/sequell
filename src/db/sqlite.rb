require 'sqlite3'

module Db
  class Sqlite
    attr_reader :filename

    def initialize(filename)
      @filename = filename
    end

    def exists?
      File.exists?(self.filename)
    end

    def table_exists?(table)
      row_exists?('SELECT * FROM sqlite_master WHERE type=? AND name=?',
        'table', table)
    end

    def load_sql(sql_file)
      sql_statements(sql_file).each { |sql|
        sql = sql.strip
        self.exec(sql) unless sql.empty?
      }
    end

    def exec(query, *binds, &block)
      db.execute(query, *binds, &block)
    end

    def transaction(&block)
      db.transaction(&block)
    end

    def single_value(query, *binds)
      exec(query, *binds) { |r| return r[0] }
      nil
    end

    def row_exists?(query, *binds)
      exec(query, *binds) { |r|
        return true
      }
      false
    end

    def last_insert_row_id
      db.last_insert_row_id
    end

  protected

    def db
      @db ||= SQLite3::Database.new(self.filename)
    end

    def sql_statements(sql_file)
      File.read(sql_file).split(';')
    end
  end
end
