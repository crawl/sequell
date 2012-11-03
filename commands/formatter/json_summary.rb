require 'formatter/summary'
require 'ostruct'

module Formatter
  class JsonSummary < Summary
    def format
      unless self.primary_grouping_field
        raise "JSON summary can only be used for grouped results"
      end

      extractor = self.create_data_extractor

      { :fields => [primary_grouping_field.name, primary_count_field.name],
        :data => self.data_rows(extractor) }
    end

    def primary_grouping_field
      @primary_grouping_field ||= find_primary_grouping_field
    end

    def primary_count_field
      @primary_count_field ||= find_primary_count_field
    end

    def data_rows(extractor)
      @summary.sorted_row_values.map { |row|
        data_row(row, extractor)
      }
    end

    def create_data_extractor
      if @summary.extra_fields.size > 0
        extra_fields = @summary.extra_fields
        field = extra_fields.find { |f| f.numeric? }
        if field
          n = extra_fields.index(field)
          return lambda { |row|
            row.value_string(row.extra_values[n], field).to_i
          }
        end
      end

      lambda { |row| row.counts[0] }
    end

  private
    def find_primary_grouping_field
      @summary.group_fields[0]
    end

    def find_primary_count_field
      @summary.extra_fields[-1] || OpenStruct.new(:name => 'N')
    end

    def data_row(row, extractor)
      [row.key, extractor.call(row)]
    end
  end
end
