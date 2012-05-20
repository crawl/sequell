module Sql
  class TimestampFormat
    FORMATS = [
      [/^\d{4}\d{2}\d{2}\d{6}$/, "YYYYMMDDHH24MISS"],
      [/^\d{4}\d{2}\d{2}\d{4}$/, "YYYYMMDDHH24MI"],
      [/^\d{4}\d{2}\d{2}\d{2}$/, "YYYYMMDDHH24"],
      [/^\d{4}\d{2}\d{2}$/, "YYYYMMDD"],
      [/^\d{4}\d{2}$/, "YYYYMM"],
      [/^\d{4}$/, "YYYY"]
    ]

    def self.format_string(timestamp_value)
      for regex, format in FORMATS
        return format if timestamp_value =~ regex
      end
      raise StandardError, "Bad timestamp value: #{timestamp_value}"
    end
  end
end
