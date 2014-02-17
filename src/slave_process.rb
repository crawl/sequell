require 'open3'
require 'json_serializer'

class SlaveProcess
  SINGLETONS = { }

  def self.process(command_line, serializer=JsonSerializer.new)
    p = self.new(command_line, serializer)
    if block_given?
      begin
        yield p
      ensure
        p.destroy!
      end
    else
      p
    end
  end

  def self.singleton(group, command_line)
    singleton = SINGLETONS[group] ||= self.create_singleton(command_line)
    if block_given?
      yield singleton
    else
      singleton
    end
  end

  def self.create_singleton(commandline)
    singleton = self.new(commandline)
    at_exit {
      singleton.destroy!
    }
    singleton
  end

  attr_reader :commandline
  attr_reader :serializer
  attr_reader :output, :input, :error, :wait_thread

  def initialize(commandline, serializer=JsonSerializer.new)
    @commandline = commandline
    @serializer = serializer
  end

  def output
    connect!
    @output
  end

  def input
    connect!
    @input
  end

  def error
    connect!
    @error
  end

  def wait_thread
    connect!
    @wait_thread
  end

  def puts(text)
    input.write(text)
    input.write("\n")
    input.flush
  end

  def readline
    output.readline
  end

  def write_data(input)
    self.puts(serializer.write(input))
  end

  def read_data
    serializer.read(self.readline)
  end

  def pid
    return nil unless self.wait_thread
    self.wait_thread.pid
  end

  def destroy!
    return unless self.pid
    Process.kill('TERM', self.pid)
  end

private

  def connect!
    return if @output
    @input, @output, @error, @wait_thread = Open3.popen3(self.commandline)
  end
end
