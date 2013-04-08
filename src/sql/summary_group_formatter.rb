module Sql
  class SummaryGroupFormatter
    DEFAULT_FORMAT = '${n_x}${.} ${%} [${n_ratio};${x}]'
    DEFAULT_PARENT_FORMAT = '${n_x}${.} ${%} (${child})'

    def self.format_cache
      @format_cache ||= { }
    end

    def self.parent_format(format=nil)
      self.format(format || DEFAULT_PARENT_FORMAT)
    end

    def self.child_format(format=nil)
      self.format(format || DEFAULT_FORMAT)
    end

    def self.format(format)
      format_cache[format] ||= self.new(format)
    end

    def initialize(format)
      @format = format or raise "No format?"
    end

    def format(row)
      @format.gsub(/\$\{([^}]+)\}/) { |m|
        format_key_value($1, row)
      }.gsub(/ +/, ' ').
        gsub(/([\[(])[;,]/, '\1').gsub(/[;,]([\])])/, '\1').
        gsub(/\(\s*\)|\[\s*\]/, '').strip
    end

    def format_key_value(key, row)
      case key
      when 'n_x'
        row.count_prefix
      when '.'
        row.key_display_value
      when '%'
        row.percentage_string
      when 'n_ratio'
        row.count_ratio_percentage
      when 'x'
        row.extra_field_value_string
      when 'child'
        row.subrows_string
      else
        "\${#{key}}"
      end
    end
  end
end
