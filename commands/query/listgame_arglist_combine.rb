require 'sql/query_argument_normalizer'

module Sql
  class ListgameArglistCombine
    # Combines to arrays of listgame arguments into one, correctly
    # handling keyword-style arguments at the head of the secondary list.
    # Example:  [ '*', 'killer=orc' ], [ 'xom' ]
    #        => [ '*', 'xom', 'killer=orc']
    def self.apply(arguments_a, arguments_b)
      result = self.clone(arguments_a)
      secondary = QueryArgumentNormalizer.normalize(arguments_b)
      for arg in secondary do
        if arg !~ OPMATCH
          result.insert(0, arg)
        else
          result << arg
        end
      end
      result
    end

    def self.clone(args)
      args.map { |x| x.dup }
    end
  end
end
