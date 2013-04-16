require 'json'
require 'env'

class CommandContext
  SUBCOMMAND_NESTING_LIMIT = 30

  def self.extra_argument_lists
    @extra_args ||= find_extra_arglists
  end

  def self.subcommand?
    ENV['SUBCOMMAND']
  end

  def self.subcommand_context
    depth = (ENV['SUBCOMMAND_DEPTH'] || '0').to_i + 1
    # if depth > SUBCOMMAND_NESTING_LIMIT
    #   raise "Subcommand recursion limit exceeded"
    # end
    Env.with(subcommand: 'y', subcommand_depth: (depth + 1).to_s) {
      yield
    }
  end

  def self.show_title?
    !subcommand?
  end

  def self.default_join
    ', '
  end

  def self.default_nick
    ARGV[1]
  end

  def self.command_words
    command_line.split()
  end

  def self.command_line
    ARGV[2]
  end

  def self.command_arguments
    command_words[1 .. -1]
  end

  def self.command
    command_words[0]
  end

  attr_accessor :arguments, :opts, :command_line

  def initialize(args=nil, command=nil)
    @original_arguments = args || self.class.command_arguments
    @arguments = @original_arguments.dup
    @command = command || self.class.command
    @command_line = self.class.command_line
    @opts = { }
  end

  def argument_string
    self.arguments.join(' ')
  end

  def command
    @command
  end

  def default_nick
    ARGV[1]
  end

  def first
    @arguments.first
  end

  def [](key)
    @opts[key]
  end

  def has_arguments?
    !@arguments.empty?
  end

  def extract_options!(*keys)
    @arguments, opts = extract_options(@arguments, *keys)
    @opts.merge!(opts)
  end

  def strip_switch!(switch)
    return nil unless @arguments[0] == switch
    shift!
  end

  def shift!
    @arguments.shift
  end

private
  def self.find_extra_arglists
    json = ENV['EXTRA_ARGS_JSON']
    return [] unless json
    JSON.parse(json)
  end
end
