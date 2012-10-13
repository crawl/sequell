require 'cmd/option_parser'

module Sql
  class QueryString
    attr_reader :args, :original_args, :argument_string

    def initialize(argument_string)
      self.argument_string = argument_string
      @original_args = @args.dup
    end

    def argument_string= (argument_string)
      @argument_string = argument_string
      @args = argument_string.split()[1 .. -1]
    end

    # Extract option flags from the arguments and return them.
    def extract_options!(*options)
      parser = Cmd::OptionParser.new(@args)
      parsed_options = parser.parse!(*options)
      @args = parser.args
      parsed_options
    end

    def [](index)
      @args[index]
    end

    def to_a
      @args
    end
  end
end
