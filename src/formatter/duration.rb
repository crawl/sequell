module Formatter
  class Duration
    def self.display(durseconds)
      minutes = durseconds / 60
      seconds = durseconds % 60
      hours = minutes / 60
      minutes = minutes % 60
      days = hours / 24
      hours = hours % 24

      timestr = sprintf("%02d:%02d:%02d", hours, minutes, seconds)
      if days > 0
        timestr = "#{days}, #{timestr}"
      end
      timestr
    end

    def self.parse(value)
      m = /^(?:(\d+),\s*)?(?:(?:(\d+):)?(\d+):)?(\d+)$/.match(value)
      raise "Bad duration: #{value}" unless m
      ((m[1] || 0).to_i * 86400) +
        ((m[2] || 0).to_i * 60 * 60) +
        ((m[3] || 0).to_i * 60) + (m[4] || 0).to_i
    end
  end
end
