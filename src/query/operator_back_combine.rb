require 'query/grammar'

module Query
  class OperatorBackCombine
    # First combination: if we have args that start with an operator,
    # combine them with the preceding arg. For instance
    # ['killer', '=', 'steam', 'dragon'] will be combined as
    # ['killer=', 'steam', 'dragon']
    def self.apply(args)
      cargs = []
      opstart = %r!^(#{operators.keys.map { |o| Regexp.quote(o) }.join('|')})!;
      for arg in args do
        if !cargs.empty? && arg =~ opstart
          cargs.last << arg
        else
          cargs << arg
        end
      end
      merge_negated_parens(cargs)
    end

    def self.merge_negated_parens(args)
      str = args.join(' ').gsub(/! #{Query::Grammar::QUOTED_OPEN_PAREN}/,
        "!#{Query::Grammar::OPEN_PAREN}").split(' ')
    end

    def self.operators
      Query::Grammar::OPERATORS
    end
  end
end
