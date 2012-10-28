require 'date'

module Sql
  class Date
    def self.log_date(sql_date)
      if sql_date.is_a?(DateTime)
        sql_date = sql_date.strftime('%Y-%m-%d %H:%M:%S')
      else
        sql_date = sql_date.to_s
      end
      if sql_date =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/
        # Note we're munging back to POSIX month (0-11) here.
        $1 + sprintf("%02d", $2.to_i - 1) + $3 + $4 + $5 + $6 + 'S'
      else
        sql_date
      end
    end

    def self.display_date(sql_date)
      if sql_date.is_a?(DateTime)
        sql_date.strftime('%Y-%m-%d %H:%M:%S')
      else
        sql_date.to_s
      end
    end
  end
end
