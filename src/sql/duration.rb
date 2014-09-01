require 'formatter/duration'

module Sql
  class Duration
    def self.display_value(duration)
      Formatter::Duration.display(duration)
    end
  end
end
