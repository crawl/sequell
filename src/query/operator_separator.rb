module Query
  class OperatorSeparator
    # Applies whitespace around grouping parentheses.
    def self.apply(args)
      cargs = []
      for arg in args do
        if arg =~ %r/#{Regexp.quote(OPEN_PAREN)}(\S+)/ then
          cargs << OPEN_PAREN
          cargs << $1
        elsif arg =~ %r/^(\S+)#{Regexp.quote(CLOSE_PAREN)}$/ then
          cargs << $1
          cargs << CLOSE_PAREN
        elsif arg =~ %r/^(\S*)#{BOOLEAN_OR_Q}(\S*)$/ then
          cargs << $1 unless $1.empty?
          cargs << BOOLEAN_OR
          cargs << $2 unless $2.empty?
        else
          cargs << arg
        end
      end
      cargs.length > args.length ? self.apply(cargs) : cargs
    end
  end
end
