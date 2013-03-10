module Query
  class OperatorSeparator
    # Applies whitespace around grouping parentheses.
    def self.apply(args)
      cargs = []
      for arg in args do
        if arg =~ %r/#{Regexp.quote(Query::Grammar::OPEN_PAREN)}(\S+)/ then
          cargs << Query::Grammar::OPEN_PAREN
          cargs << $1
        elsif arg =~ %r/^(\S+)#{Regexp.quote(Query::Grammar::CLOSE_PAREN)}$/ then
          cargs << $1
          cargs << Query::Grammar::CLOSE_PAREN
        elsif arg =~ %r/^(\S*)#{Query::Grammar::BOOLEAN_OR_Q}(\S*)$/ then
          cargs << $1 unless $1.empty?
          cargs << Query::Grammar::BOOLEAN_OR
          cargs << $2 unless $2.empty?
        else
          cargs << arg
        end
      end
      cargs.length > args.length ? self.apply(cargs) : cargs
    end
  end
end
