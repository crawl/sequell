module Crawl
  class Gods
    def initialize(god_abbrev_map)
      @god_abbrev_map = god_abbrev_map
    end

    def god_full_name(abbreviation)
      @god_abbrev_map[abbreviation]
    end

    def god_abbreviations
      @god_abbreviations ||= @god_abbrev_map.keys
    end

    def god_resolve_name(abbr)
      return unless abbr =~ /^[a-z]+$/i
      match = self.god_abbreviations.find { |g| abbr.downcase.index(g) == 0 }
      match && self.god_full_name(match)
    end
  end
end
