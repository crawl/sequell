require 'helper'

module Query
  class Nick
    def self.any?(nick)
      nick && nick =~ /^!?[*]$/
    end

    def self.aliases(nick)
      return [nick[1..-1]] if nick =~ /^:/
      nick_aliases(nick)
    end
  end
end
