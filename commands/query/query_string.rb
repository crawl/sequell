require 'cmd/option_parser'
require 'sql/listgame_arglist_combine'

module Sql
  class QueryString
    attr_reader :args, :original_args, :argument_string, :context_word

    # Creates a QueryString for a raw !lg/!lm command line, i.e.
    # discarding the first word (!lg / !lm)
    def self.command_line(argument_string)
      args = argument_string.split()
      context_word = args[0]
      self.new(args[1 .. -1].join(' '), context_word)
    end

    def initialize(argument_string, context_word=nil)
      self.argument_string = argument_string
      @original_args = @args.dup
      @context_word = context_word
    end

    def argument_string= (argument_string)
      @argument_string = argument_string
      @args = argument_string.split().map { |x| x.strip }.find_all { |x|
        !x.empty?
      }
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

    def to_s
      self.argument_string
    end

    def + (other)
      combined_args = ListgameArglistCombine.apply(@args, other.args)
      QueryString.new(combined_args.join(' '), self.context_word)
    end
  end
end
