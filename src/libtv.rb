#! /usr/bin/env ruby

require 'gserver'
require 'helper'
require 'sqlop/tv_view_count'
require 'fileutils'

module TV
  @@tv_args = nil
  @channel_server = !!ENV['TV_CHANNEL_SERVER']

  TV_QUEUE_DIR = 'tmp/tv'
  TV_QUEUE_FILE = 'tv.queue'
  TV_LOCK_FILE = 'tv.queue.lock'
  TV_LOG_FILE = 'tv.queue.log'

  SPEED_MIN = 0.1
  SPEED_MAX = 100

  def self.queue_dir
    TV_QUEUE_DIR
  end

  def self.queue_dir_file(file)
    FileUtils.mkdir_p(self.queue_dir)
    File.join(self.queue_dir, file)
  end

  def self.queue_file
    queue_dir_file(TV_QUEUE_FILE)
  end

  def self.lock_file
    queue_dir_file(TV_LOCK_FILE)
  end

  def self.log_file
    queue_dir_file(TV_LOG_FILE)
  end

  def self.channel_server?
    @channel_server
  end

  def self.as_channel_server
    old_channel_server = @channel_server
    old_env = ENV['TV_CHANNEL_SERVER']
    begin
      @channel_server = true
      ENV['TV_CHANNEL_SERVER'] = 'y'
      yield
    ensure
      @channel_server = old_channel_server
      ENV['TV_CHANNEL_SERVER'] = old_env
    end
  end

  # Serves TV requests to FooTV instances.
  class TVServ < GServer
    def initialize(port = 21976, host = "0.0.0.0")
      puts "Starting TV notification server."
      @started = Time.now.strftime("%s").to_i
      @clients = []
      @mutex = Mutex.new
      @monitor = nil
      super(port, host, Float::MAX, $stderr, true)
    end

    def bootstrap_client
      queue = []
      class << queue
        def mutex
          @tmutex ||= Mutex.new
        end
      end

      # Create the mutex now.
      queue.mutex

      @mutex.synchronize do
        @clients << queue
        unless @monitor
          @monitor = Thread.new { run_monitor }
        end
      end
      queue
    end

    def run_monitor
      begin
        while true
          open(TV.queue_file, 'r+') do |af|
            TV.flock(af, File::LOCK_EX) do |f|
              lines = f.readlines
              f.truncate(0)

              new_lines = lines.find_all do |line|
                if line =~ /^(\d+) .*/
                  start = $1.to_i
                  start >= @started
                end
              end

              clients = @mutex.synchronize { @clients }
              clients.each do |c|
                c.mutex.synchronize do
                  c.push(*new_lines)
                end
              end
            end
          end
          sleep 3
        end
      rescue
        puts "Monitor: #$!"
      end
    end

    def serve(sock)
      queue = nil
      begin
        queue = bootstrap_client()
        while true
          queue.mutex.synchronize do
            queue.each do |q|
              sock.write(q)
              sock.flush
            end
            queue.clear
          end
          sleep 3
        end
      rescue
        puts "Ack: #$!"
      ensure
        if queue
          @mutex.synchronize do
            @clients.delete_if { |q| q.object_id == queue.object_id }
          end
        end
      end
    end
  end

  def self.flock(file, mode)
    success = file.flock(mode)
    if success
      begin
        res = yield file
        return res
      ensure
        file.flock(File::LOCK_UN)
      end
    end
    nil
  end

  def self.oflock(filename, mode)
    open(filename, 'w') do |of|
      flock(of, mode) do |f|
        return yield(f)
      end
    end
    nil
  end

  def self.launch_daemon()
    return if fork()

    begin
      Process.setsid
    ensure
    end

    # Try for a lock, but do not block
    oflock(TV.lock_file, File::LOCK_EX | File::LOCK_NB) do |f|

      # Be a good citizen:
      logfile = File.open(TV.log_file, 'w')
      logfile.sync = true
      STDOUT.reopen(logfile)
      STDERR.reopen(logfile)
      STDIN.close()

      # Start the notification server and wait on it.
      tv = TVServ.new
      tv.start()
      tv.join()
    end
    exit 0
  end

  def self.parse_tv_args(opts)
    hash = { }
    for key in opts.keys
      if key == :cancel || key == :nuke
        self.parse_tv_arg(hash, key.to_s)
      elsif key == :tv
        value = opts[key]
        next unless value.is_a?(String)
        value.split(':').each { |v| self.parse_tv_arg(hash, v) }
      end
    end
    hash
  end

  def self.parse_seek_num(seek, num, allow_end=false)
    seekname = seek == '<' ? 'seek-back' : 'seek-after'
    expected = allow_end ? 'T<turncount>, number, ">" or "$"' : 'T<turncount> or number'
    if (num !~ /^t[+-]?\d+$/i && num !~ /^[-+]?\d+(?:\.\d+)?$/ &&
        (!allow_end || (num != '$' && num != '>')))
      raise "Bad seek argument for #{seekname}: #{num} (#{expected} expected)"
    end
    num
  end

  def self.read_playback_speed(speed_string)
    speed = speed_string.to_f
    if speed < SPEED_MIN || speed > SPEED_MAX
      raise "Playback speed must be between #{SPEED_MIN} and #{SPEED_MAX}"
    end
    speed
  end

  def self.parse_tv_arg(hash, key)
    if key == 'cancel' or key == 'nuke'
      hash[key] = 'y'
    else
      prefix = key[0..0].downcase
      rest = key[1 .. -1].strip
      case prefix
      when '<'
        hash['seekbefore'] = parse_seek_num(prefix, rest)
      when '>'
        hash['seekafter'] = parse_seek_num(prefix, rest, true)
      when 't'
        hash['seekafter'] = parse_seek_num('<', prefix + rest)
      when 'x'
        hash['playback_speed'] = read_playback_speed(rest)
      else
        raise "Unrecognised TV option: #{key}"
      end
    end
  end

  def self.with_tv_opts(argv, tv_command = false)
    opts = %w/tv/
    opts += %w/cancel nuke/ if tv_command

    args, opts = extract_options(argv, *opts)
    old_args = @@tv_args
    begin
      @@tv_args = parse_tv_args(opts)
      yield args, opts
    rescue
      puts $! unless $!.is_a?(NameError)
      raise
    ensure
      @@tv_args = old_args
    end
  end

  def self.seek_to_game_end?
    @@tv_args && @@tv_args['seekafter'] == '>'
  end

  def self.request_game(g)
    # Launch a daemon that keeps a server socket open for interested
    # parties (i.e. C-SPLAT) to listen in.
    launch_daemon()

    open(TV.queue_file, 'a') do |file|
      flock(file, File::LOCK_EX) do |f|
        # Make sure we're really at eof.
        f.seek(0, IO::SEEK_END)
        stripped = g
        f.puts "#{Time.now.strftime('%s')} #{munge_game(stripped)}"
      end
    end
  end

  def self.request_game_verbosely(n, g, who)
    summary = short_game_summary(g)
    tv = 'FooTV'

    unless TV.channel_server?
      if @@tv_args && @@tv_args['nuke']
        puts "FooTV playlist clear requested by #{who}."
      else
        suffix = @@tv_args && @@tv_args['cancel'] ? ' cancel' : ''
        puts "#{n}. #{summary}#{suffix} requested for #{tv}."
      end

      Sqlop::TVViewCount.increment(g)
      g['req'] = ARGV[1]
    end

    if @@tv_args
      for k in @@tv_args.keys
        g[k] = @@tv_args[k]
      end
    end

    if TV.channel_server?
      puts "#{n}. :#{munge_game(g)}:"
      return
    else
      request_game(g)
    end
  end
end
