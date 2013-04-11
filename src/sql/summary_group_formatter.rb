require 'query/text_template'

module Sql
  class SummaryGroupFormatter
    DEFAULT_FORMAT = '${n_x}${.} ${%} [${n_ratio};${x}]'
    DEFAULT_PARENT_FORMAT = '${n_x}${.} ${%} (${child})'
    DEFAULT_AGGREGATE_FORMAT = '$keyed_x'

    def self.format_cache
      @format_cache ||= { }
    end

    def self.parent_format(format=nil, template_properties=nil)
      self.format(format || DEFAULT_PARENT_FORMAT, template_properties)
    end

    def self.child_format(format=nil, template_properties=nil)
      self.format(format || DEFAULT_FORMAT, template_properties)
    end

    def self.aggregate_format(format=nil, template_properties=nil)
      self.format(format || DEFAULT_AGGREGATE_FORMAT, template_properties)
    end

    def self.format(format, template_properties)
      format_cache[format] ||= self.new(format, template_properties)
    end

    def initialize(format, expansion_provider=nil)
      @format = ::Query::TextTemplate.new(format) or raise "No format?"
      @expansion_provider = expansion_provider
    end

    def format(row)
      @format.expand { |key|
        format_key_value(key, row)
      }
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
      when '@x'
        row.extra_field_value_array
      when 'keyed_x'
        row.annotated_extra_val_array.join('; ')
      when '@keyed_x'
        row.annotated_extra_val_array
      when '@child'
        row.subrows_array
      when 'child'
        row.subrows_string
      else
        @expansion_provider && @expansion_provider[key]
      end
    end
  end
end
