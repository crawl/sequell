require 'formatter/summary'
require 'formatter/util'
require 'formatter/extra_field_extractor'
require 'ostruct'

module Formatter
  class JsonSummary < Summary
    MAX_BAR_GROUPS = 25

    def format
      unless self.primary_grouping_field
        raise "JSON summary can only be used for grouped results"
      end

      fields = [primary_grouping_field.to_s] + count_field_names
      extractor = self.create_data_extractor
      { :fields => fields,
        :data => self.data_rows(extractor) }
    end

    # The Y series is determined by extra fields in x=agg(foo),agg(bar) forms.
    def extra_field_series?
      @extra_numeric_fields && !@extra_numeric_fields.empty?
    end

    # The Y series is determined by the stacked grouping two-field
    # s=foo,bar forms.
    def stacked_grouping_query?
      @summary.query_group.group_count == 2
    end

    # The stacked grouping field in a multi-field s=foo,bar,baz form
    # (i.e. 'bar' in the example).
    def stacked_group
      @stacked_group ||= @summary.query_group.query_groups[1]
    end

    # The display names of each of the fields (1 or more) used as Y
    # axis series.
    def count_field_names
      count_fields.map(&:name)
    end

    def ratio_query?
      @summary.ratio_query?
    end

    def primary_grouping_field
      @primary_grouping_field ||= find_primary_grouping_field
    end

    def count_fields
      @count_fields ||= find_count_fields
    end

    def data_rows(extractor)
      @summary.sorted_row_values.map { |row|
        data_row(row, extractor)
      }
    end

    def perc?
      @perc
    end

    def create_data_extractor
      if stacked_grouping_query?
        stacked_group_extractor
      elsif extra_field_series?
        @perc = true if ratio_query?
        ExtraFieldExtractor.extractor(@summary, @extra_numeric_fields)
      elsif primary_grouping_field.percentage
        @perc = true
        lambda { |row|
          [Formatter.ratio(row.count, @summary.count)]
        }
      else
        lambda { |row|
          [row.counts[0]]
        }
      end
    end

  private
    def find_primary_grouping_field
      @summary.group_fields[0]
    end

    def find_count_fields
      return summary_count_fields if stacked_grouping_query?

      @extra_numeric_fields = @summary.extra_fields.find_all { |f|
        f.numeric?
      }
      if @extra_numeric_fields.empty? && ratio_query?
        return [OpenStruct.new(:name => "#{ratio_title} %")]
      end
      @extra_numeric_fields.empty? ? [OpenStruct.new(:name => 'N')] :
                                     @extra_numeric_fields
    end

    def summary_count_fields
      group_set = Set.new
      @summary.sorted_row_values.each { |row|
        subrows = row.subrows
        subrows.each { |subrow|
          key_val = subrow.key_display_value
          key_val = key_val.to_s if key_val == true || key_val == false
          group_set << key_val
        }
      }
      count_fields = group_set.to_a.sort.map { |name|
        OpenStruct.new(:name => name)
      }
      count_fields.reverse! if count_fields.size == 2 && stacked_group.boolean?

      @field_indexes = Hash[count_fields.each_with_index.map { |field, i|
        [field.name, i]
      }]

      if count_fields.size == 2 && stacked_group.boolean?
        return [stacked_group.name.to_s,
                "!" + stacked_group.name.to_s].map { |name|
          OpenStruct.new(:name => name)
        }
      end
      count_fields
    end

    def stacked_group_extractor
      indexes = @field_indexes or
        raise "Field indexes not discovered for grouping query"
      n_indexes = indexes.size

      boolean = count_fields.size == 2 && stacked_group.boolean?
      lambda { |row|
        result = [0] * n_indexes
        row.subrows.each { |subrow|
          key = subrow.key_display_value
          key = key.to_s if boolean
          field_index = indexes[key]
          result[field_index] = subrow.count if field_index
        }
        result
      }
    end

    def ratio_title
      @summary.query_group[1].argstr
    end

    def data_row(row, extractor)
      [row.key_value] + extractor.call(row)
    end
  end
end
