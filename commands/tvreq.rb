#! /usr/bin/ruby

# Requests that C-SPLAT play the specified game.

require 'commands/helper'
require 'commands/sqlhelper'
require 'gserver'

help("Requests that C-SPLAT play the specified game. All !lg game-selector options apply.")

QUEUE_FILE = 'tv.queue'
LOCK_FILE = 'tv.queue.lock'
LOG_FILE = 'tv.queue.log'

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
        open(QUEUE_FILE, 'r+') do |af|
          flock(af, File::LOCK_EX) do |f|
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

def flock(file, mode)
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

def oflock(filename, mode)
  open(filename, 'w') do |of|
    flock(of, mode) do |f|
      return yield(f)
    end
  end
  nil
end

def launch_daemon()
  return if fork()

  begin
    Process.setsid
  ensure
  end

  # Try for a lock, but do not block
  oflock(LOCK_FILE, File::LOCK_EX | File::LOCK_NB) do |f|

    # Be a good citizen:
    logfile = File.open(LOG_FILE, 'w')
    logfile.sync = true
    STDOUT.reopen(logfile)
    STDERR.reopen(logfile)
    STDIN.close()

    # And start the notification server.
    tv = TVServ.new
    tv.start()
    tv.join()
  end
  exit 0
end

def request_game(g)
  # Launch a daemon that keeps a server socket open for interested
  # parties (i.e. C-SPLAT) to listen in.
  launch_daemon()

  open(QUEUE_FILE, 'a') do |file|
    flock(file, File::LOCK_EX) do |f|
      # Make sure we're really at eof.
      f.seek(0, IO::SEEK_END)

      # Give bare minimum info to reduce traffic.
      stripped = {
        'name' => g['name'],
        'start' => g['start'],
        'end' => g['end'],
        # Who requested the game.
        'req' => g['req'],

        # These aren't required, but are useful to see.
        'char' => g['char'],
        'place' => g['place'],
        'xl' => g['xl']
      }
      f.puts "#{Time.now.strftime('%s')} #{munge_game(stripped)}"
    end
  end
end

def main
  n, game, selectors =
    sql_find_game(ARGV[1], ARGV[2].split()[1 .. -1] + [ "splat=y" ])
  raise "No games for #{selectors}." unless game

  summary = short_game_summary(game)
  raise "#{n}. #{summary} is not a splat." unless game['splat'] == 'y'
  puts "#{n}. #{summary} requested for C-SPLAT."

  game['req'] = ARGV[1]
  request_game(game)

rescue
  puts $!
  raise
end

main()
