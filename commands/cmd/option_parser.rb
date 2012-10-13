module Cmd
  class OptionParser
    attr_reader :args

    def initialize(args)
      @args = args
    end

    def parse!(*keys)
      keyset = Set.new(keys)
      final_args = []
      options_found = { }
      for arg in @args
        if arg =~ /^-(\w+)(?::(.*))?$/ && keyset.include?($1)
          found[$1.to_sym] = $2 || true
        else
          final_args << arg
        end
      end
      @args = final_args
      options_found
    end
  end
end
