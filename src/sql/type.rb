require 'sql/date'
require 'sql/duration'
require 'sql/version_number'

module Sql
  class Type
    def self.type(string_or_type)
      return string_or_type if string_or_type.is_a?(self)
      self.new(string_or_type || '')
    end

    def self.type_categories
      @type_categories ||= SQL_CONFIG['type-categories']
    end

    def initialize(type_string)
      @type_string = type_string.sub(/(?:.*?)([A-Z]*[\W]*)$/, '\1')
    end

    def type
      @type ||= find_type
    end

    def raw_type
      @raw_type ||= find_raw_type
    end

    def category
      @category ||= (Type.type_categories[self.type] || 'S')
    end

    def any?
      self.type == '*'
    end

    def case_sensitive?
      self.type == 'S'
    end

    def text?
      self.category == 'S'
    end

    def date?
      self.type == 'D'
    end

    def duration?
      self.type == 'ET'
    end

    def version?
      self.type == 'VER'
    end

    def numeric?
      self.category == 'I'
    end

    def integer?
      self.type == 'I'
    end

    def real?
      self.type == 'F'
    end

    def boolean?
      self.type == '!'
    end

    def display_value(value, display_format=nil)
      return Sql::Duration.display_value(value) if self.duration?
      return Sql::Date.display_date(value, display_format) if self.date?
      numeric_value = value.is_a?(BigDecimal) || value.is_a?(Float)
      if self.integer?
        return value.to_i
      end
      if self.real?
        return strip_padding_zeros(sprintf("%.2f", value.to_f))
      end
      value
    end

    def log_value(raw_value)
      case
      when self.real?
        strip_padding_zeros(sprintf("%.2f", raw_value.to_f))
      when self.numeric?
        raw_value.to_i
      when self.date?
        Sql::Date.log_date(raw_value)
      else
        raw_value
      end
    end

    def comparison_value(raw_value)
      return Sql::VersionNumber.version_numberize(raw_value) if self.version?
      return raw_value.to_f if self.real?
      return raw_value.to_i if self.integer?
      return (raw_value || '').downcase if self.text?
      return raw_value.to_s if self.boolean?
      raw_value
    end

    def compatible?(other)
      other = Type.type(other)
      return true if self.any? || other.any?
      self.category == other.category
    end

    alias :type_match? :compatible?

    def == (other)
      self.type == Type.type(other).type
    end

    def to_s
      "Type[#{type}]"
    end

  private
    def find_type
      case raw_type
      when 'PK'
        'I'
      when /^I/
        'I'
      else
        raw_type
      end
    end

    def find_raw_type
      if @type_string =~ /([A-Z]+)/
        $1
      elsif @type_string =~ /!/
        '!'
      elsif @type_string =~ /\*/
        '*'
      else
        ''
      end
    end

    def strip_padding_zeros(value)
      value.sub(/([.]\d*?)0+$/, '\1').sub(/[.]$/, '')
    end
  end
end
