require 'fileutils'
require 'libtv'
require 'henzell/config'

module TV
  CHANNEL_DIR  = 'dat/tv'
  CHANNEL_FILE = File.join(CHANNEL_DIR, 'channels.def')

  class Channels
    def self.instance
      self.new
    end

    def initialize
      @channels = { }
      self.load
    end

    def all
      @channels.keys.sort.map { |key|
        [key, self.channel_named(key)]
      }
    end

    def canonical_channel_name(channel_name)
      return channel_name if @channels.include?(channel_name)
      lower_name = channel_name.downcase
      @channels.keys.find { |key| key.downcase == lower_name }
    end

    def channel_named(channel_name)
      @channels[canonical_channel_name(channel_name)]
    end

    def add_channel(channel_name, definition)
      channel_name = canonical_channel_name(channel_name) || channel_name
      self.delete_channel(channel_name)
      @channels[channel_name] = definition
    end

    def delete_channel(channel_name)
      @channels.delete(canonical_channel_name(channel_name))
    end

    def load
      with_file { |f|
        f.each { |line|
          line = line.strip
          @channels[$1] = $2 if line =~ /^(\S+) (.*)/
        }
      }
    end

    def save
      with_file { |f|
        f.truncate(0)
        @channels.keys.sort.each { |channel_name|
          f.puts "#{channel_name} #{@channels[channel_name]}"
        }
      }
    end

  private
    def create_directory
      FileUtils.mkdir_p(channel_dir)
    end

    def channel_dir
      Henzell::Config.file_path(CHANNEL_DIR)
    end

    def channel_file
      Henzell::Config.file_path(CHANNEL_FILE)
    end

    def with_file(mode='a+')
      create_directory
      File.open(channel_file, mode) { |file|
        TV.flock(file, File::LOCK_EX) { |file|
          file.seek(0)
          yield(file)
        }
      }
    end
  end

  class ChannelManager
    def self.list_channels
      channels = Channels.instance
      channels.all.map { |name, definition| "#{name} #{definition}" }.join("\n")
    end

    def self.query_channel(channel_name)
      definition = Channels.instance.channel_named(channel_name)
      if definition
        puts "Channel #{channel_name} => #{definition}"
      else
        puts "Channel #{channel_name} does not exist"
      end
    end

    def self.add_channel(channel_name, definition)
      c = Channels.instance
      c.add_channel(channel_name, definition)
      c.save
      puts "Added channel #{c.canonical_channel_name(channel_name)} => #{definition}"
    end

    def self.delete_channel(channel_name)
      c = Channels.instance
      definition = c.delete_channel(channel_name)
      if definition
        c.save
        puts "Deleted channel #{channel_name} => #{definition}"
      else
        puts "No channel named #{channel_name}"
      end
    end
  end
end
