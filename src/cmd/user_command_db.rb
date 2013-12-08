require 'sqlite3'
require 'henzell/config'

module Cmd
  class UserCommandDb
    COMMAND_DB = 'dat/user_commands.db'

    def self.db
      @db ||= self.new(Henzell::Config.file_path(COMMAND_DB))
    end

    def initialize(db_file)
      @db_file = db_file
    end

    def commands
      query_all('user_commands')
    end

    def keywords
      query_all('user_keywords')
    end

    def functions
      query_all('user_functions')
    end

    def function_exists?(function_name)
      exists?('user_functions', function_name)
    end

    def command_exists?(command_name)
      exists?('user_commands', command_name)
    end

    def keyword_exists?(keyword)
      exists?('user_keywords', keyword)
    end

    def query_function(function_name)
      query('user_functions', function_name)
    end

    def query_command(command_name)
      query('user_commands', command_name)
    end

    def query_keyword(keyword)
      query('user_keywords', keyword)
    end

    def define_function(name, definition)
      delete_function(name)
      insert('user_functions', name, definition)
    end

    def define_command(name, definition)
      delete_command(name)
      insert('user_commands', name, definition)
    end

    def define_keyword(name, definition)
      delete_keyword(name)
      insert('user_keywords', name, definition)
    end

    def delete_function(name)
      delete('user_functions', name)
    end

    def delete_command(name)
      delete('user_commands', name)
    end

    def delete_keyword(name)
      delete('user_keywords', name)
    end

  private
    def query(table, name)
      db.execute("SELECT name, definition FROM #{table} WHERE name = ?",
                 "_" + name.downcase) { |row|
        return [row[0].to_s[1..-1], row[1]]
      }
      nil
    end

    def query_all(table)
      commands = []
      db.execute("SELECT name, definition FROM #{table} ORDER BY name") { |row|
        commands << [row[0].to_s[1..-1], row[1]]
      }
      commands
    end

    def exists?(table, name)
      db.execute("SELECT * FROM #{table} WHERE name = ?",
        "_" + name.downcase) { |row|
        return true
      }
      false
    end

    def insert(table, name, definition)
      db.execute("INSERT INTO #{table} (name, definition) VALUES (?, ?)",
        "_" + name.downcase, definition)
    end

    def delete(table, name)
      db.execute("DELETE FROM #{table} WHERE name = ?", "_" + name.downcase)
    end

    def db
      @db ||= open_db
    end

    def open_db
      new_db = SQLite3::Database.new(@db_file)
      new_db.type_translation = false
      begin
        new_db.execute(<<SCHEMA)
CREATE TABLE user_functions (name STRING PRIMARY KEY, definition STRING);
SCHEMA

        new_db.execute(<<SCHEMA)
CREATE TABLE user_keywords (name STRING PRIMARY KEY, definition STRING);
SCHEMA
        new_db.execute(<<SCHEMA)
CREATE TABLE user_commands (name STRING PRIMARY KEY, definition STRING);
SCHEMA
      rescue
        # Ignore if tables already existed.
      end
      new_db
    end
  end
end
