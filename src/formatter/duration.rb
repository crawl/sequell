module Formatter
  class Duration
    def self.display(durseconds)
      dur = durseconds.to_i
      days = dur / 3600 / 24
      years = days / 365
      days = days % 365
      prefix = [years > 0 && "#{years}y", days > 0 && "#{days}d"].find_all { |x| x }.join("+")
      prefix = "#{prefix}+" unless prefix.empty?
      sprintf("%s%d:%02d:%02d", prefix, (dur / 3600) % 24,
        (dur % 3600) / 60, dur % 60)
    end

    def self.parse(value)
      parts = value.split('+')
      sum = 0
      for part in parts
        sum += parse_duration_part(part)
      end
      sum
    end

    def self.parse_duration_part(part)
      if part =~ /^(\d+)y$/i
        $1.to_i * 365 * 86400
      elsif part =~ /^(\d+)d$/i
        $1.to_i * 86400
      elsif part =~ /^(?:(?:(\d+):)?(\d+):)?(\d+)$/
        (($1 || 0).to_i * 60 * 60) +
          (($2 || 0).to_i * 60) + ($3 || 0).to_i
      else
        raise "Bad duration: #{part}"
      end
    end
  end
end
