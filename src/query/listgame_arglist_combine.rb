require 'query/grammar'

module Query
  class ListgameArglistCombine
    include Grammar

    # Combines two arrays of listgame arguments into one, correctly
    # handling keyword-style arguments at the head of the secondary list.
    # Example:  [ '*', 'killer=orc' ], [ 'xom' ]
    #        => [ '*', 'killer=orc', '((', 'xom', '))' ]
    def self.apply(arguments_a, arguments_b)
      a_string = arguments_a.join(' ')
      b_string = arguments_b.join(' ')
      a_tail = a_string.index('?:') ? a_string.sub(/^.*\?:/, '?:') : ''
      a_string = a_string.sub(/^(.*)\?:.*/, '\1')
      [a_string, b_string, a_tail].join(' ').split(' ')
    end
  end
end
