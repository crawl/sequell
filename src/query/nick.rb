require 'helper'
require 'nick/entry'

module Query
  class Nick
    def self.any?(nick)
      nick && nick =~ /^!?[*]$/
    end

    def self.mapping(nick)
      return ::Nick::Entry.stub(nick[1..-1]) if nick =~ /^:/
      NickDB[nick]
    end
  end
end
