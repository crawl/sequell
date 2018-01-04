require 'pg'

DBNAME = ENV['SEQUELL_DBNAME'] || 'sequell'
DBUSER = ENV['SEQUELL_DBUSER'] || 'sequell'
DBPASS = ENV['SEQUELL_DBPASS'] || 'sequell'

# Replaces ? bind variables in a query string with postgres $1, $2, ... binds
def postgres_binds(query_with_binds)
  bind_index = 0
  query_with_binds.gsub('?') { |match|
    bind_index += 1
    "$#{bind_index}"
  }
end

class DBHandle
  def initialize(db)
    @db = db
  end

  def close
    @db.close
  end

  def with(&action)
    begin
      action.call(self)
    ensure
      self.close
    end
  end

  def get_first_value(query, *binds)
    self.execute(query, *binds) { |row|
      return row[0]
    }
    nil
  end

  def execute(query, *binds)
    query_result = @db.exec(postgres_binds(query), binds)
    begin
      query_result.each_row { |row|
        yield row
      }
    ensure
      query_result.clear
    end
  end

  def do(query, *binds)
    @db.exec(postgres_binds(query), binds).clear
  end
end

class PgNumericDecoder < PG::SimpleDecoder
  def decode(number_text, tuple=nil, field=nil)
    number_text.to_f
  end
end

class SQLConnection
  def self.connection
    DBHandle.new(self.raw_type_mapped_connection)
  end

  def self.with_connection(&action)
    self.connection.with(&action)
  end

  def self.initialize_type_registry
    return if @type_registry_initialized
    PG::BasicTypeRegistry.register_type(0, 'citext', PG::TextEncoder::String, PG::TextDecoder::String)
    PG::BasicTypeRegistry.register_type(0, 'numeric', PG::TextEncoder::String, PgNumericDecoder)
    @type_registry_initialized = true
  end

  def self.raw_type_mapped_connection
    self.initialize_type_registry
    connection = PG.connect(dbname: DBNAME, user: DBUSER, password: DBPASS)
    connection.type_map_for_queries = PG::BasicTypeMapForQueries.new(connection)
    connection.type_map_for_results = PG::BasicTypeMapForResults.new(connection)
    connection.exec("set time zone 'UTC'").clear
    connection
  end
end
