require 'fileutils'

require 'henzell/config'
require 'nick/entry'

module Nick
  ##
  # A database of mappings from IRC nicks to their names on public
  # game servers, optionally accompanied by additional query filters.
  class DB
    def self.default_db_path
      @default_db ||= Henzell::Config.file_path(
        ENV['HENZELL_TEST'] ? 'dat/nicks-test.map' : 'dat/nicks.map')
    end

    def self.default
      @default ||= self.new(default_db_path)
    end

    attr_reader :path

    def initialize(path)
      @path = path
      @nickmap = nil
    end

    def reload!
      @nickmap = nil
    end

    def save!
      FileUtils.mkdir_p(File.dirname(path))
      tmp = path + '.tmp'
      File.open(tmp, 'w') do |f|
        for nick in nickmap.keys.sort
          entry = nickmap[nick]
          f.puts(entry.serialize) unless entry.stub?
        end
      end
      File.rename(tmp, path)
    end

    ##
    # Appends a nick mapping for +nick+ => +expansions+; if there are existing
    # mappings for +nick+, expansions are merely added to those, otherwise
    # a new nick mapping is created.
    #
    # If +expansions+ and +conditions+ are both nil or empty, returns the
    # existing nick mapping for +nick+.
    def append(nick, expansions, conditions=nil)
      return self[nick] unless (expansions && !expansions.empty?) || conditions
      res = self[nick].append(expansions || [], conditions)
      if res.stub?
        self.delete(nick)
        return res
      end
      self[nick] = res
    end

    ##
    # Appends a parsed Nick::Entry, otherwise behaving exactly like #append.
    def append_nick(nick)
      return self[nick.nick] if nick.empty?
      append(nick.nick, nick.raw_expansions, nick.listgame_conditions)
    end

    ##
    # Deletes a nick from the db, returning the deleted nick. Returns
    # a stub nick if the nick did not exist in the db.
    def delete(nick)
      nickmap.delete(canonicalize nick) || Entry.stub(nick)
    end

    ##
    # Return a nick mapping given a nick, *or* a stub if there is no
    # nickmapping. A stub maps the input nick to itself and responds
    # with +true+ to Nick::Entry#stub?
    def [](nick)
      nickmap[canonicalize nick] || Entry.stub(nick)
    end

    ##
    # Assigns a Nick::Entry to a nick, overwriting the existing entry
    # if present. Use #add if you want to update existing nicks.
    def []=(nick, entry)
      raise "Nick mapping must be a Nick::Entry" unless entry.is_a?(Entry)
      nickmap[canonicalize nick] = entry
    end

  private

    def nickmap
      @nickmap ||= (load_nicks || {})
    end

    def canonicalize(nick)
      nick.to_s.downcase
    end

    def load_nicks
      return unless File.exists?(path)
      aliases = { }
      File.open(path) do |f|
        f.each_line do |line|
          entry = Entry.parse(line)
          aliases[entry.nick] = entry if entry
        end
      end
      aliases
    end
  end
end
