require 'sql/date'
require 'sql/duration'
require 'sql/version_number'

module Sql
  class TypeError < StandardError
  end

  class Type
    @@raw_type_cache = { }

    def self.type(string_or_type)
      return string_or_type if string_or_type.is_a?(self)
      self.new(string_or_type || '')
    end

    def self.promoted_type(a, b)
      return a unless a.compatible?(b)
      promotion = promotion_map[a.type] || promotion_map[b.type]
      if promotion && promotion.category.compatible?(a) &&
          promotion.category.compatible?(b)
        return self.type(promotion.target).with_unit(a.unit || b.unit)
      end
      self.type(a.category).with_unit(a.unit || b.unit)
    end

    def self.promotion_map
      @promotion_map ||= build_promotion_map
    end

    def self.type_categories
      @type_categories ||= SQL_CONFIG['type-categories']
    end

    attr_accessor :unit

    def initialize(type_string)
      @type_string = type_string.sub(/(?:.*?)([A-Z]*[\W]*)$/, '\1')
    end

    def type
      @type ||= find_type
    end

    def coerce_expr(sql)
      return "EXTRACT(EPOCH FROM #{sql})" if interval?
      sql
    end

    def convert(value)
      return value if self.any? || self.duration_type?
      return float_value(value) if self.real?
      return int_value(value) if self.integer?
      return value.to_i if self.numeric?
      return timestamp_value(value) if self.date?
      dcvalue = value.downcase
      if self.boolean?
        return dcvalue == 'y' || dcvalue == 't' || dcvalue == 'true' ||
          dcvalue == '1'
      end
      value
    end

    def timestamp_value(value)
      return "#{value}0101" if value =~ /^\d{4}$/
      return "#{value}01" if value =~ /^\d{4}\d{2}$/
      value
    end

    def value_is_number?(val)
      val.to_s =~ /^[+-]?(?:\d+(?:[.]\d*)?|[.]\d+)$/
    end

    def int_value(val)
      unless value_is_number?(val)
        raise TypeError.new("'#{val}' is not an integer")
      end
      val.to_i
    end

    def float_value(val)
      unless value_is_number?(val)
        raise TypeError.new("#{val} is not a number")
      end
      val.to_f
    end

    def raw_type
      @raw_type ||= find_raw_type
    end

    def category
      @category ||= (Type.type_categories[self.type] || 'S')
    end

    def with_unit(unit)
      return self if unit == self.unit
      clone = self.dup
      clone.unit = unit
      clone
    end

    def unit
      return @unit if @unit
      return 'seconds' if self.duration_type?
      nil
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

    def duration_type?
      self.type == 'ET' || self.type == 'ETD'
    end

    def interval?
      self.type == 'ETD'
    end

    def duration?
      self.unit == 'seconds'
    end

    def version?
      self.type == 'VER'
    end

    def vault?
      self.type == 'MAP'
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
      return vault_name(value) if self.vault?
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
      when self.date?
        Sql::Date.log_date(raw_value)
      when self.duration?
        display_value(raw_value)
      when self.real?
        strip_padding_zeros(sprintf("%.2f", raw_value.to_f))
      when self.numeric?
        raw_value.to_i
      else
        raw_value
      end
    end

    def comparable_expr(expr)
      return expr unless self.case_sensitive?
      "CAST(#{expr} AS CITEXT)"
    end

    def comparison_value(raw_value)
      return Sql::VersionNumber.version_numberize(raw_value) if self.version?
      return raw_value.to_f if self.real?
      return raw_value.to_i if self.integer?
      return (raw_value || '').downcase if self.text?
      return raw_value.to_s if self.boolean?
      raw_value
    end

    def applied_to(other_type)
      return other_type if self.any?
      return self if !other_type || other_type.any?

      unit = self.unit || other_type.unit
      return self.with_unit(unit) if other_type == '*' || self == other_type
      self.class.type(self.category).with_unit(self.unit || other_type.unit)
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

    def + (other)
      self.class.promoted_type(self, other).with_unit(self.unit || other.unit)
    end

    def to_s
      identifiers = [type, unit].compact.join(';')
      "Type[#{identifiers}]"
    end

    def to_sql
      return 'int' if self.integer?
      return 'real' if self.real?
      nil
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
      @@raw_type_cache[@type_string] ||=
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

    def vault_name(value)
      value.gsub(/(?<!;) /, '_')
    end

    def self.build_promotion_map
      Hash[ SQL_CONFIG['type-promotions'].map { |promotion_target, category|
          [promotion_target, OpenStruct.new(target: promotion_target,
                                            category: self.type(category))]
      } ]
    end
  end
end
