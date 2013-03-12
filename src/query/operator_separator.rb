module Query
  class OperatorSeparator
    # Applies whitespace around grouping parentheses.
    def self.apply(args)
      cargs = []
      for arg in args do
        if arg =~ %r/^(\S*)(!?#{QUOTED_OPEN_PAREN})(\S+)/ then
          cargs << $1 unless $1.empty?
          cargs << $2
          cargs << $3
        elsif arg =~ %r/^(\S+)#{QUOTED_CLOSE_PAREN}(\S*)$/ then
          cargs << $1
          cargs << Query::Grammar::CLOSE_PAREN
          cargs << $2 unless $2.empty?
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
