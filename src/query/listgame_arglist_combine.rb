require 'query/grammar'

module Query
  class ListgameArglistCombine
    # Combines two arrays of listgame arguments into one, correctly
    # handling keyword-style arguments at the head of the secondary list.
    # Example:  [ '*', 'killer=orc' ], [ 'xom' ]
    #        => [ '*', 'killer=orc', '((', 'xom', '))' ]
    def self.apply(arguments_a, arguments_b)
      res = arguments_a.join(" ") + " " + Query::Grammar::OPEN_PAREN + " " +
        arguments_b.join(" ") + " " + Query::Grammar::CLOSE_PAREN
      res.split(' ')
    end
  end
end
