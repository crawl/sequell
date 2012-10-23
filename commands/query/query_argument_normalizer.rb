require 'query/operator_back_combine'
require 'query/operator_separator'
require 'query/arg_combine'

module Query
  # Normalizes an array of listgame-style arguments, combining or
  # separating individual words to be easier to analyze.
  class QueryArgumentNormalizer
    # Normalizes an argument list (as an array)
    def self.normalize(args_list, options={ :back_combine => true,
                                            :recombine => true })
      self.new(args_list.map { |x| x.dup }, options).normalize
    end

    def initialize(args, options)
      @args = args
      @options = options
    end

    def normalize
      @args = self.operator_back_combine(@args) if @options[:back_combine]
      @args = self.operator_separate(@args)
      @args = self.combine(@args) if @options[:recombine]
      @args
    end

    # First combination: if we have args that start with an operator,
    # combine them with the preceding arg. For instance
    # ['killer', '=', 'steam', 'dragon'] will be combined as
    # ['killer=', 'steam', 'dragon']
    def operator_back_combine(args)
      OperatorBackCombine.apply(args)
    end

    def operator_separate(args)
      OperatorSeparator.apply(args)
    end

    def combine(args)
      ArgCombine.apply(args)
    end
  end
end
