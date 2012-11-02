require 'formatter/summary'
require 'ostruct'

module Formatter
  class JsonSummary < Summary
    def format
      unless self.primary_grouping_field
        raise "JSON summary can only be used for grouped results"
      end

      { :fields => [primary_grouping_field.name, primary_count_field.name],
        :data => self.data_rows }
    end

    def primary_grouping_field
      @primary_grouping_field ||= find_primary_grouping_field
    end

    def primary_count_field
      @primary_count_field ||= find_primary_count_field
    end

    def data_rows
      @summary.sorted_row_values.map { |row|
        data_row(row)
      }
    end

  private
    def find_primary_grouping_field
      @summary.group_fields[0]
    end

    def find_primary_count_field
      @summary.extra_fields[-1] || OpenStruct.new(:name => 'N')
    end

    def data_row(row)
      [row.key, row.counts[0]]
    end
  end
end
