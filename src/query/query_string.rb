require 'cmd/option_parser'
require 'query/listgame_arglist_combine'
require 'query/query_string_template'
require 'command_context'

module Query
  class QueryString
    attr_reader :args, :argument_string, :context_word
    attr_reader :original_args, :original_string

    # Creates a QueryString for a raw !lg/!lm command line, i.e.
    # discarding the first word (!lg / !lm)
    def self.command_line(argument_string)
      args = argument_string.split()
      context_word = args[0]
      self.new(args[1 .. -1].join(' '), context_word)
    end

    def self.query(thing)
      return thing if thing.is_a?(self)
      self.new(thing)
    end

    def initialize(argument_string, context_word=nil)
      if argument_string.is_a?(Array)
        argument_string = argument_string.join(' ')
      end
      self.argument_string = argument_string
      @original_string = argument_string.dup
      @original_args = @args.dup
      @context_word = context_word
    end

    def empty?
      @original_string.nil? || @original_string.empty?
    end

    def dup
      QueryString.new(self.argument_string.dup, @context_word)
    end

    def first
      @args[0]
    end

    def original
      QueryString.new(@original_string, @context_word)
    end

    def argument_string= (argument_string)
      @argument_string = argument_string
      @args = argument_string.split().map { |x| x.strip }.find_all { |x|
        !x.empty?
      }
    end

    def args= (args_list)
      @args = args_list.map { |x| x.dup.strip }.find_all { |x| !x.empty? }
      @argument_string = @args.join(' ')
    end

    def empty?
      @args.empty?
    end

    def normalize!
      self.args = QueryArgumentNormalizer.normalize(@args)
    end

    # Extract option flags from the arguments and return them.
    def extract_options!(*options)
      parser = Cmd::OptionParser.new(@args)
      parsed_options = parser.parse!(*options)
      @args = parser.args
      parsed_options
    end

    def option!(option)
      options = extract_options!(option)
      options[option]
    end

    def find(&block)
      @args.find(&block)
    end

    def extract!(&block)
      arg = @args.find(&block)
      @args.delete(arg) if arg
      arg
    end

    def [](index)
      @args[index]
    end

    def command_line
      context_word + " " + argument_string
    end

    def to_a
      @args
    end

    def to_s
      self.argument_string
    end

    # Returns a string suitable for display, stripping spurious
    # enclosing parentheses where possible.
    def display_string
      op_match = /#{SORTEDOPS.map { |o| Regexp.quote(o) }.join("|")}/
      popen = Regexp.quote(OPEN_PAREN)
      pclose = Regexp.quote(CLOSE_PAREN)
      text = self.to_s
      text.gsub(/#{popen}(.*?)#{pclose}/) { |m|
        payload = $1.dup
        count = 0
        payload.gsub(op_match) do |pm|
          count += 1
          pm
        end
        if count == 1
          payload.strip
        else
          OPEN_PAREN + payload.strip + CLOSE_PAREN
        end
      }.strip
    end

    def + (other)
      return self.dup unless other && !other.empty?

      other = QueryString.query(other)
      combined_args = ListgameArglistCombine.apply(@args, other.args)
      QueryString.new(combined_args.join(' '), self.context_word)
    end
  end
end
