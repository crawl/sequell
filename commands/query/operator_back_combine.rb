module Sql
  class OperatorBackCombine
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
