module Query
  class OperatorBackCombine
    # First combination: if we have args that start with an operator,
    # combine them with the preceding arg. For instance
    # ['killer', '=', 'steam', 'dragon'] will be combined as
    # ['killer=', 'steam', 'dragon']
    def self.apply(args)
      cargs = []
      opstart = %r!^(#{OPERATORS.keys.map { |o| Regexp.quote(o) }.join('|')})!;
      for arg in args do
        if !cargs.empty? && arg =~ opstart
          cargs.last << arg
        else
          cargs << arg
        end
      end
      cargs
    end
  end
end
