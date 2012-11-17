#! /usr/bin/env ruby

# Persistent cache.
module PCache
  require 'sqlite3'

  DATE_FORMAT = '%Y%m%dT%H%M%S'
  DB_FILE = 'tmp/pcache.db'

  @@db = nil

  def self.pcache_file
    require 'fileutils'
    FileUtils.mkdir_p(File.dirname(DB_FILE))
    DB_FILE
  end

  def self.create
    if not @@db
      @@db = SQLite3::Database.new(self.pcache_file)
      begin
        @@db.execute(<<SQL)
CREATE TABLE pcache (key STRING PRIMARY KEY, value STRING, vtstamp STRING);
SQL
      rescue
        # Ignore table create failure
      end
    end
  end

  def self.format_time(time)
    time.strftime(DATE_FORMAT)
  end

  def self.parse_time(time)
    DateTime.strptime(time, DATE_FORMAT)
  end

  def self.add(key, value, timestamp = DateTime.now)
    self.create
    @@db.execute('DELETE FROM pcache WHERE key = ?', key)
    @@db.execute('INSERT INTO pcache (key, value, vtstamp) VALUES (?, ?, ?)',
                 key, value, self.format_time(timestamp))
  end

  # Queries the cache for the given key and returns the result if found
  # and more recent than the given timestamp, or if the timestamp is nil.
  def self.find(key, timestamp = nil)
    self.create
    @@db.execute('SELECT value, vtstamp FROM pcache WHERE key = ?', key) do
      |row|
      rowts = self.parse_time(row[1])
      if rowts >= timestamp
        return row[0]
      end
    end
    nil
  end
end
