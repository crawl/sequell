module LearnDB
  ROOT = ENV['HENZELL_ROOT'] || '.'
  DB_FILE = ENV['LEARNDB'] ||
    File.join(ROOT, 'dat/learn.db')

  SCHEMA_FILE = File.join(ROOT, 'config/learndb.sql')

  class DB
    def self.default
      @default ||= self.new(DB_FILE)
    end

    def self.fuzzy_lookup_slave
      require 'slave_process'
      @slave ||=
        SlaveProcess.singleton('ldb-similar',
                               "perl -I#{ROOT}/lib #{ROOT}/scripts/ldb-similar")
    end

    def initialize(file)
      @file = file
    end

    def valid_term?(name)
      canonical_name = canonical_term(name)
      canonical_name && !canonical_name.empty?
    end

    def real_term(name)
      self.entry(name).canonical_name
    end

    def canonical_term(name)
      name.tr(' ', '_').tr('[]', '').gsub(/^_+|_+$/, '').gsub(/_{2,}/, '_')
    end

    def candidate_terms(name)
      p = self.class.fuzzy_lookup_slave
      p.write_data(term: name)
      p.read_data["candidates"]
    end

    def terms_matching(pattern)
      terms = []
      each_term { |term|
        terms << term if term =~ pattern
      }
      terms
    end

    def entries_matching(pattern)
      matches = []
      each_term { |term|
        entry = self.entry(term)
        defs = entry.definitions
        for i in 0...defs.size
          if defs[i] =~ pattern
            matches << entry[i + 1]
          end
        end
      }
      matches
    end

    def entry(entry_name)
      Entry.new(self, canonical_term(entry_name))
    end

    def each_term
      db.exec('SELECT term FROM terms ORDER BY term ASC') { |r|
        yield r[0]
      }
    end

    def term_exists?(term)
      definition_count(term) > 0
    end

    def definition_count(term)
      query = <<QUERY
SELECT MAX(seq) FROM definitions
 WHERE term_id = (SELECT id FROM terms where term = ?)
QUERY
      db.single_value(query, canonical_term(term)) || 0
    end

    def definition_at(term, index=1)
      query = <<QUERY
SELECT definition FROM definitions
 WHERE term_id = (SELECT id FROM terms where term = ?)
   AND seq = ?
QUERY
      db.single_value(query, term, index)
    end

    def db
      @db ||= open_db
    end

  private
    def open_db
      require 'db/sqlite'
      db = Db::Sqlite.new(@file)
      unless db.table_exists?('terms') && db.table_exists?('definitions')
        db.load_sql(SCHEMA_FILE)
      end
      db
    end
  end

  class LearnDBError < StandardError
  end

  class MissingEntryError < LearnDBError
  end

  class EntryIndexError < LearnDBError
  end

  class LookupResult
    attr_reader :entry, :index, :size, :text, :text_only
    attr_accessor :original_term, :term
    def initialize(entry, index, size, text, text_only=false)
      @entry = entry
      @index = index
      @size = size
      @text = text
      @text_only = text_only
    end

    def to_s
      return text if text_only
      if original_term != term
        trail = [original_term, term, entry.canonical_name]
      else
        trail = [entry.canonical_name]
      end
      trail = trail.compact.uniq
      "#{trail.join(' ~ ')}[#{index}/#{size}]: #{text}"
    end
  end

  class Entry
    attr_reader :name
    attr_accessor :original_term

    def initialize(db, name)
      @db = db
      @name = name
    end

    def canonical_name
      @canonical_name ||=
        (dbh.single_value('SELECT term FROM terms WHERE term = ?', @name) ||
         @name)
    end

    def with_original_term(term)
      copy = self.dup
      copy.original_term = term
      copy
    end

    def rename_to(newname)
      raise "#{name} doesn't exist" unless self.exists?
      unless @db.valid_term?(newname)
        raise "Cannot rename #{name} -> #{newname}: #{newname} is invalid"
      end
      newname = @db.canonical_term(newname)
      if newname.downcase != @name.downcase && @db.term_exists?(newname)
        raise "Cannot rename #{name} -> #{newname}, #{newname} exists"
      end
      dbh.exec('UPDATE terms SET term = ? WHERE term = ?', newname, @name)
    end

    def exists?
      size > 0
    end

    def size
      @db.definition_count(@name) || 0
    end

    def normalize_index(index, purpose=:query)
      return 1 if index == 0
      original = index
      max = (self.size || 0) + (purpose == :append ? 1 : 0)
      index += max + 1 if index < 0
      if index > max || index <= 0
        raise EntryIndexError.new("Index #{original} out of bounds for #{@name} (valid range: [1, #{max}])")
      end
      index
    end

    def definitions
      res = []
      dbh.exec('SELECT definition FROM definitions ' +
               ' WHERE term_id = (SELECT id FROM terms WHERE term = ?) ' +
               ' ORDER BY seq ASC', @name) { |r|
        res << r[0]
      }
      res
    end

    def [](index)
      index = normalize_index(index)
      result(index, @db.definition_at(@name, index))
    rescue EntryIndexError
      nil
    end

    def []=(index, value)
      index = normalize_index(index)
      dbh.exec('UPDATE definitions SET definition = ? WHERE ' +
              '       term_id = (SELECT id FROM terms WHERE term = ?) AND ' +
              '       seq = ?', value, @name, index)
      value
    end

    def term_id
      dbh.single_value('SELECT id FROM terms WHERE term = ?', @name)
    end

    def add(value, index=-1)
      dbh.transaction {
        id = self.term_id
        unless id
          dbh.exec('INSERT INTO terms (term) VALUES (?)', @name)
          id = dbh.last_insert_row_id
        end

        entry_count = self.size
        index = (entry_count || 0) + 1 unless index
        index = normalize_index(index, :append)
        if entry_count && index <= entry_count
          increment_definition_seq(id, index)
        end

        insert_definition(id, value, index)
      }
      index
    end

    def delete(index=nil)
      if index.nil?
        dbh.exec('DELETE FROM terms WHERE term = ?', @name)
      else
        index = normalize_index(index)
        dbh.transaction {
          delete_value(index)
          if exists?
            decrement_definition_seq(self.term_id, index)
          else
            self.delete(nil)
          end
        }
      end
    end

    def to_s
      @name
    end

  private
    def result(index, text)
      return nil if text.nil?
      LookupResult.new(self, index, self.size, text)
    end

    def increment_definition_seq(id, index)
      dbh.exec(<<UPDATE_INDICES, id, index)
UPDATE definitions SET seq = seq + 1
 WHERE term_id = ? AND seq >= ?
UPDATE_INDICES
    end

    def decrement_definition_seq(id, index)
      dbh.exec(<<UPDATE_INDICES, id, index)
UPDATE definitions SET seq = seq - 1
 WHERE term_id = ? AND seq > ?
UPDATE_INDICES
    end

    def insert_definition(id, value, index)
      dbh.exec(<<INSERT_DEF, id, value, index)
INSERT INTO definitions (term_id, definition, seq)
     VALUES (?, ?, ?)
INSERT_DEF
    end

    def delete_value(index)
      dbh.exec(<<DELETE_VALUE, @name, index)
DELETE FROM definitions
      WHERE term_id = (SELECT id FROM terms WHERE term = ?)
        AND seq = ?
DELETE_VALUE
    end

    def canonical_term(name)
      raise "Invalid term: #{name}" unless @db.valid_term?(name)
      LearnDB.canonical_term(name)
    end

    def dbh
      @db.db
    end
  end
end
