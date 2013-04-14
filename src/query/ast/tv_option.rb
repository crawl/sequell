module Query
  module AST
    class TVOption < Option
      SPEED_MIN = 0.1
      SPEED_MAX = 50

      attr_reader :opts

      def initialize(name, args)
        super
        @opts = { }
        parse_tv_opts!
      end

      def [](key)
        @opts[key.to_sym]
      end

      def []=(key, val)
        @opts[key.to_sym] = val
      end

      def valid_channel_name?(name)
        name && name =~ /^[^\s\/\\]{2,}$/
      end

      def channel_name(g)
        name = self[:channel]
        return name if self.valid_channel_name?(name)
        "#{g['name']}:#{g['char']}@#{g['xl']}.T#{@g['turn']}"
      end

      def seek_to_game_end?
        @opts[:seekafter] == '>'
      end

    private
      def parse_tv_opts!
        option_arguments.each { |key|
          parse_option(key)
        }
      end

      def parse_option(raw_key)
        key = raw_key.downcase
        if key == 'cancel' or key == 'nuke'
          @opts[key.to_sym] = 'y'
        elsif key == 'new'
          @opts[:channel] = ''
        elsif raw_key =~ /channel=(.*)/i
          self[:channel] = $1.to_s
          unless self.valid_channel_name?(self[:channel])
            raise "Invalid channel name: #{self[:channel]}"
          end
        else
          prefix = key[0..0].downcase
          rest = key[1 .. -1].strip
          case prefix
          when '<'
            @opts[:seekbefore] = parse_seek_num(prefix, rest)
          when '>'
            @opts[:seekafter] = parse_seek_num(prefix, rest, true)
          when 't'
            @opts[:seekafter] = parse_seek_num('<', prefix + rest)
          when 'x'
            @opts[:playback_speed] = read_playback_speed(rest)
          else
            raise "Unrecognised TV option: #{key}"
          end
        end
      end

      def parse_seek_num(seek, num, allow_end=false)
        seekname = seek == '<' ? 'seek-back' : 'seek-after'
        expected = allow_end ? 'T<turncount>, number, ">" or "$"' : 'T<turncount> or number'
        if (num !~ /^t[+-]?\d+$/i && num !~ /^[-+]?\d+(?:\.\d+)?$/ &&
            (!allow_end || (num != '$' && num != '>')))
          raise "Bad seek argument for #{seekname}: #{num} (#{expected} expected)"
        end
        num
      end

      def read_playback_speed(speed_string)
        speed = speed_string.to_f
        if speed < SPEED_MIN || speed > SPEED_MAX
          raise "Playback speed must be in range [#{SPEED_MIN},#{SPEED_MAX}]"
        end
        speed
      end
    end
  end
end
