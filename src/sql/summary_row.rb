require 'date'
require 'sql/date'
require 'sql/summary_group_formatter'

module Sql
  class SummaryRow
    attr_accessor :counts, :extra_fields, :extra_values, :fields, :key
    attr_accessor :summary_field_spec, :parent
    attr_reader :subrows
    attr_reader :summary_reporter

    def initialize(summary_reporter,
        summary_fields, count,
        extra_fields,
        extra_values)
      @summary_reporter = summary_reporter
      @parent = @summary_reporter

      @summary_field_spec = nil

      query = summary_reporter.query

      summarise_fields = query.summarise
      @summary_field_spec = summarise_fields.args[0] if summarise_fields
      @fields = summary_fields
      @key =
        if summary_fields
          if summary_fields.size == 1
            summary_fields[0]
          else
            summary_fields.join('@@')
          end
        end
      @counts = count.nil? ? nil : [count]
      @extra_fields = extra_fields
      @extra_values = extra_values.map { |e| [ e ] }
      @subrows = nil
    end

    def query
      @summary_reporter.query
    end

    def group_formatter
      @group_formatter ||=
        SummaryGroupFormatter.child_format(query.ast.key_value(:fmt))
    end

    def master_formatter
      @master_formatter ||=
        SummaryGroupFormatter.parent_format(query.ast.key_value(:pfmt))
    end

    def count
      @counts.nil? ? 0 : @counts[0]
    end

    def zero_counts
      @counts ? @counts.map { |x| 0 } : []
    end

    def add_count!(extra_counts)
      extra_counts.size.times do |i|
        @counts[i] += extra_counts[i]
      end
    end

    def subrows= (rows)
      @subrows = rows
      if @subrows
        @counts = zero_counts
        for row in @subrows
          row.parent = self
          add_count! row.counts
        end
      end
    end

    def self.subrow_from_fullrow(fullrow, key_override=nil, subrows=nil)
      row = SummaryRow.new(fullrow.summary_reporter,
        [fullrow.fields[-1]],
        fullrow.count,
        fullrow.extra_fields,
        fullrow.extra_values)
      row.extra_fields = fullrow.extra_fields
      row.extra_values = fullrow.extra_values
      row.counts = fullrow.counts
      row.key = key_override unless key_override.nil?
      row.subrows = subrows
      row
    end

    def key
      @key.nil? ? :identity : @key
    end

    def compare_key
      my_key = self.key
      @summary_field_spec.comparison_value(my_key)
    end

    def key_value
      @key.is_a?(BigDecimal) ? @key.to_f : @key
    end

    def key_display_value
      format_value(self.key, @summary_field_spec)
    end

    def extend!(size)
      extend_array(@counts, size)
      for ev in @extra_values do
        extend_array(ev, size)
      end
    end

    def extend_array(array, size)
      if not array.nil?
        (array.size ... size).each do
          array << 0
        end
      end
    end

    def combine!(sr)
      @counts << sr.counts[0] if not sr.counts.nil?

      extra_index = 0
      for eval in sr.extra_values do
        @extra_values[extra_index] << eval[0]
        extra_index += 1
      end
    end

    def <=> (sr)
      sr.count <=> count
    end

    def master_string
      return [counted_keys, percentage_string].find_all { |x|
        !x.to_s.empty?
      }.join(" ")
    end

    def subrows_string
      @subrows.map { |s| s.to_s }.join(", ")
    end

    def master_group_to_s
      master_formatter.format(self)
    end

    def to_s
      if @subrows
        master_group_to_s
      elsif !@key.nil?
        group_formatter.format(self)
      else
        annotated_extra_val_string
      end
    end

    def percentage_string
      if !@summary_reporter.ratio_query?
        if @summary_field_spec && @summary_field_spec.percentage
          return "(" + percentage(@counts[0], @parent.count) + ")"
        end
      end
      ""
    end

    def count_prefix
      if count_string == '1'
        ''
      else
        "#{count_string}x "
      end
    end

    def counted_keys
      count_prefix.to_s + key_display_value.to_s
    end

    def count_string
      @counts.reverse.join("/")
    end

    def count_ratio_percentage
      if @counts.size > 1
        percentage(@counts[1], @counts[0])
      else
        ''
      end
    end

    def extra_field_value_string
      @extra_values.each_with_index.map { |x, i|
        value_string(x, @extra_fields.fields[i])
      }.join(";")
    end

    def extra_val_string
      allvals = []
      allvals << self.count_ratio_percentage
      allvals << self.extra_field_value_string
      es = allvals.find_all { |x| !x.empty? }.join(";")
      es.empty? ? es : "[" + es + "]"
    end

    def annotated_extra_val_string
      res = []
      index = 0
      fields = @extra_fields && @extra_fields.fields
      @extra_values.each do |ev|
        res << annotated_value(fields && fields[index], ev)
        index += 1
      end
      res.join("; ")
    end

    def annotated_value(field, value)
      "#{field || 'N'}=#{value_string(value, field)}"
    end

    def format_value(v, field=nil)
      return field.display_value(v) if field
      if v.is_a?(BigDecimal) || v.is_a?(Float)
        rawv = sprintf("%.2f", v)
        rawv.sub!(/([.]\d*?)0+$/, '\1')
        rawv.sub!(/[.]$/, '')
        rawv
      elsif v.is_a?(DateTime)
        Sql::Date.display_date(v)
      else
        v
      end
    end

    def value_string(value, field=nil)
      sz = value.size
      if not [1,2].index(sz)
        raise "Unexpected value array size: #{value.size}"
      end
      if sz == 1
        format_value(value[0], field)
      else
        short = value.reverse.map { |v|
          format_value(v, field)
        }.join("/") + " (#{percentage(value[1], value[0])})"
      end
    end

    def percentage(num, den)
      den == 0 ? "-" : sprintf("%.2f%%", num.to_f * 100.0 / den.to_f)
    end
  end
end
