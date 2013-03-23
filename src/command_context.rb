require 'json'

class CommandContext
  def self.extra_argument_lists
    @extra_args ||= find_extra_arglists
  end

  def self.command_words
    ARGV[2].split()
  end

  def self.command_arguments
    command_words[1 .. -1]
  end

  def self.command
    command_words[0]
  end

  attr_accessor :arguments, :opts

  def initialize(args=nil, command=nil)
    @original_arguments = args || self.class.command_arguments
    @arguments = @original_arguments.dup
    @command = command || self.class.command
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
