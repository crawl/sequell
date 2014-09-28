module Nick
  ##
  # A nick entry, mapping an IRC nick to a set of expansions, with optional
  # listgame conditions attached.
  class Entry
    ##
    # Parses an entry string as produced by Entry#serialize into a nick entry.
    # Returns +nil+ if the string is not a valid nick mapping.
    def self.parse(line)
      conditions = nil
      if line =~ /\((.*)\)/
        conditions = $1
        line = line.gsub(/\((.*)\)/, ' ')
      end
      if line =~ /^(\S+)(.*)$/
        nick = $1
        conditions = conditions.strip if conditions
        expansions = $2.to_s.strip.downcase.split(' ')
        return self.new(nick, expansions, conditions)
      end
      nil
    end

    ##
    # Returns a stub nick mapping, i.e. a nick mapping to itself.
    def self.stub(nick)
      self.new(nick, [])
    end

    ##
    # A lowercased IRC nick.
    attr_reader :nick

    ##
    # A string of listgame conditions that must apply to satisfy this
    # nick mapping. May be +nil+ to imply an unconditional nick
    # mapping (the default).
    attr_reader :listgame_conditions

    def initialize(nick, expansions, listgame_conditions=nil)
      @nick = nick
      @expansions = expansions
      @listgame_conditions = listgame_conditions
    end

    ##
    # Returns the number of expansions for this nick.
    def size
      expansions.size
    end

    ##
    # An array of lowercased unique nick expansions, with +size+ >= 1.
    # If #stub? == +true+, returns [#nick].
    def expansions
      return [nick] if @expansions.empty? && !has_condition?
      @expansions
    end

    ##
    # An array of lowercased unique nick expansions, possibly empty.
    def raw_expansions
      @expansions
    end

    ##
    # Returns the primary (first) mapping for the nick.
    def primary
      expansions.first
    end

    ##
    # Returns #expansions joined by " ".
    def expansion_string
      expansions.join(' ')
    end

    ##
    # Returns true if #listgame_conditions is non-+nil+ and not empty.
    def has_condition?
      c = self.listgame_conditions
      !c.nil? && !c.strip.empty?
    end

    ##
    # Returns true if this entry is completely empty, viz. has no
    # expansions and has +nil+ #listgame_conditions. An entry with no
    # expansions and a blank #listgame_conditions is a #stub?, but is
    # not #empty?
    def empty?
      listgame_conditions.nil? && stub?
    end

    ##
    # Returns true if this entry just maps #nick to itself. Stubs will
    # not be saved to the nick db.
    def stub?
      !has_condition? &&
        (@expansions.empty? ||
         (@expansions.size == 1 && self.primary == nick))
    end

    ##
    # Returns +true+ if this nick mapping's explicit #expansions
    # include +expansion+.
    def include?(expansion)
      @expansions.include?(canonical_expansion expansion)
    end

    ##
    # Removes +expansion+ from this nick mapping's expansions, returning
    # +true+ if +expansion+ was a part of this mapping.
    def delete(expansion)
      deleted = !( @expansions.delete(canonical_expansion expansion) ).nil?
      @expansions = [nick] if @expansions.empty?
      deleted
    end

    ##
    # Sets nick #expansions and #listgame_conditions.
    def set(exps, conditions)
      @expansions = canonicalize(exps).uniq
      @listgame_conditions = conditions
      self
    end

    ##
    # Appends nick +expansions+ to this nick. If +conditions+ is non-+nil+,
    # *overwrites* the existing #listgame_conditions with +conditions+.
    #
    def append(exps, conditions=nil)
      @expansions = (@expansions + canonicalize(exps)).uniq
      @listgame_conditions = conditions unless conditions.nil?
      self
    end

    ##
    # Returns a display string for this nick mapping, expressed as
    #     #nick => (#listgame_conditions) #expansions
    def to_s
      if has_condition?
        "#{nick} => (#{listgame_conditions}) #{expansion_string}"
      else
        "#{nick} => #{expansion_string}"
      end.strip
    end

    ##
    # Returns this nick mapping formatted as
    #     #nick (#listgame_conditions) #expansions
    def serialize
      if has_condition?
        "#{nick} (#{listgame_conditions}) #{expansion_string}"
      else
        "#{nick} #{expansion_string}"
      end.strip
    end

  private

    def canonicalize(exps)
      exps.map { |e| canonical_expansion(e) }
    end

    def canonical_expansion(exp)
      exp.to_s.strip.downcase
    end
  end
end
