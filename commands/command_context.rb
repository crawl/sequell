class CommandContext
  def self.command_arguments
    ARGV[2].split()[1 .. -1]
  end

  attr_accessor :arguments, :opts

  def initialize
    @arguments = self.class.command_arguments
    @opts = { }
  end

  def default_nick
    ARGV[1]
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
end
