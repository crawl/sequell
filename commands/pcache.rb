#! /usr/bin/ruby

# Persistent cache.
module PCache
  require 'sqlite3'

  DATE_FORMAT = '%Y%m%dT%H%M%S'

  @@db = nil

  def self.create
    if not @@db
      @@db = SQLite3::Database.new("pcache.db")
      @@db.execute(<<SQL)
CREATE TABLE pcache (key STRING PRIMARY KEY, value STRING, timestamp STRING);
SQL
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
    @@db.execute('INSERT INTO pcache (key, value, timestamp) VALUES (?, ?, ?)',
                 key, value, self.format_time(timestamp))
  end

  # Queries the cache for the given key and returns the result if found
  # and more recent than the given timestamp, or if the timestamp is nil.
  def self.find(key, timestamp = nil)
    self.create
    @@db.execute('SELECT value, timestamp FROM pcache WHERE key = ?', key) do
      |row|
      rowts = self.parse_time(row[1])
      if rowts >= timestamp
        return row[0]
      end
    end
    nil
  end
end
