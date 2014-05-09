module Henzell
  class TtyrecSearch
    def self.ttyrecs(source, game)
      self.new(source, game).ttyrecs
    end

    attr_reader :source, :game
    def initialize(source, game)
      @source = source
      @game = game
    end

    def user
      @game['name']
    end

    def utc_epoch
      @source.utc_epoch
    end

    def tty_start
      @tty_start ||= (game_ttyrec_datetime(game, 'start') ||
                      game_ttyrec_datetime(game, 'rstart'))
    end

    def tty_end
      @tty_end ||= (game_ttyrec_datetime(game, 'end') ||
                    game_ttyrec_datetime(game, 'time'))
    end

    def short_start_time
      @short_start_time ||= self.tty_start.strftime(SHORT_DATEFORMAT)
    end

    def short_end_time
      @short_end_time ||= self.tty_end.strftime(SHORT_DATEFORMAT)
    end

    def ttyrec_urls
      self.source.ttyrec_urls
    end

    def user_ttyrec_urls
      @user_ttyrec_urls ||= self.ttyrec_urls.map { |ttyrec_url|
        user_ttyrec_url(ttyrec_url)
      }
    end

    def ttyrecs
      require 'httplist'
      all_ttyrecs =
        HttpList::find_files(self.user_ttyrec_urls, /[.]ttyrec/, tty_end) ||
        [ ]
      all_ttyrecs = unique_ttyrecs(all_ttyrecs)

      first_ttyrec_before_start = nil
      first_ttyrec_is_start = false
      found = all_ttyrecs.find_all do |ttyrec|
        filetime = ttyrec_filename_datetime_string(ttyrec.filename)
        if (filetime && short_start_time && filetime < short_start_time)
          first_ttyrec_before_start = ttyrec
        end

        if (!first_ttyrec_is_start && filetime && short_start_time &&
             filetime == short_start_time)
          first_ttyrec_is_start = true
        end

        filetime && (!short_start_time || filetime >= short_start_time) &&
          filetime <= short_end_time
      end

      if first_ttyrec_before_start && !first_ttyrec_is_start
        found = [ first_ttyrec_before_start ] + found
      end

      found
    end

  private
    def user_ttyrec_url(ttyrec_url)
      ttyrec_url + '/' + self.user + '/'
    end

    def unique_ttyrecs(urls)
      seen = Set.new
      urls.find_all { |u|
        unique_url = !seen.include?(u.filename)
        seen.add(u.filename)
        unique_url
      }
    end

    def ttyrec_filename_datetime_string(filename)
      if filename =~ /^(\d{4}-\d{2}-\d{2}\.\d{2}:\d{2}:\d{2})\.ttyrec/
        $1.gsub(/[-.:]/, '')
      elsif filename =~ /(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})[+]00:?00/
        $1.gsub(/[-:T]/, '')
      elsif filename =~ /(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+]\d{2}:\d{2})/
        date = DateTime.strptime($1, '%Y-%m-%dT%H:%M:%S%Z')
        date.new_offset(0).strftime('%Y%m%d%H%M%S')
      else
        nil
      end
    end

    def game_ttyrec_datetime(game, key=nil)
      time = morgue_time(game, key)
      return nil if time.nil?
      dt = DateTime.strptime(time + "+0000", MORGUE_DATEFORMAT + '%z')
      if self.utc_epoch && dt < self.utc_epoch
        dst = morgue_time_dst?(game, key)
        src = game['src']
        src = src + (dst ? 'D' : 'S')

        tz = source.timezone(src)
        if tz
          # Parse the time as the server's local TZ, and convert it to UTC.
          dt = DateTime.strptime(time + tz, MORGUE_DATEFORMAT + '%z').new_offset(0)
        end
      end
      dt
    end
  end
end
