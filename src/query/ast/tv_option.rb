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

      def seek_to_game_end?
        @opts[:seekafter] == '>'
      end

    private
      def parse_tv_opts!
        option_arguments.each { |key|
          parse_option(key.downcase)
        }
      end

      def parse_option(key)
        if key == 'cancel' or key == 'nuke'
          @opts[key.to_sym] = 'y'
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
