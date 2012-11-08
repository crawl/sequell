require 'helper'

module Query
  class Nick
    def self.any?(nick)
      nick && nick =~ /^!?[*]$/
    end

    def self.aliases(nick)
      nick_aliases(nick)
    end
  end
end
