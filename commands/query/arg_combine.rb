module Query
  class ArgCombine
    # Second combination: Go through the arg list and check for
    # space-split args that should be combined (such as ['killer=steam',
    # 'dragon'], which should become ['killer=steam dragon']).
    def self.apply(args)
      self.new(args).combine
    end

    def initialize(args)
      @args = args
    end

    def combine
      cargs = []
      for arg in @args do
        if (cargs.empty? || arg =~ ARGSPLITTER || arg_is_grouper?(arg) ||
            arg_is_grouper?(cargs.last) || args_uncombinable?(cargs.last, arg))
          cargs << arg
        else
          cargs.last << " " << arg
        end
      end
      cargs
    end

    def arg_is_grouper?(arg)
      [OPEN_PAREN, CLOSE_PAREN, BOOLEAN_OR].index(arg)
    end

    def args_uncombinable?(a, b)
      a =~ /^@/ || b =~ /^@/
    end
  end
end
