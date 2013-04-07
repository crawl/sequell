require 'sql/summary_row_group'
require 'sql/summary_row'
require 'formatter/text_summary'

module Sql
  class SummaryReporter
    attr_reader :query_group, :counts, :sorted_row_values

    def initialize(query_group, formatter)
      @query_group = query_group
      @q = query_group.primary_query
      @lq = query_group[-1]
      @extra = @q.extra
      @efields = @extra ? @extra.fields : nil
      @sorted_row_values = nil
      @formatter = formatter
    end

    def query
      @q
    end

    def ratio_query?
      @counts &&  @counts.size == 2
    end

    def summary(formatter=nil)
      @counts = []

      for q in @query_group do
        count = sql_count_rows_matching(q)
        @counts << count
        break if count == 0
      end

      @count = @counts[0]
      if @count == 0
        "No #{summary_entities} for #{@q.argstr}"
      else
        filter_count_summary_rows!
        formatter = formatter || @formatter || Formatter::TextSummary
        formatter.format(self)
      end
    end

    def report_summary(formatter=nil)
      puts(self.summary(formatter))
    end

    def count
      @counts[0]
    end

    def summary_count
      if @counts.size == 1
        @count == 1 ? "One" : "#{@count}"
      else
        @counts.reverse.join("/")
      end
    end

    def summary_entities
      type = @q.ctx.entity_name
      @count == 1 ? type : type + 's'
    end

    def group_fields
      group_by = @q.summarise
      group_by ? group_by.fields : []
    end

    def extra_fields
      @q.extra ? @q.extra.fields : []
    end

    def filter_count_summary_rows!
      group_by = @q.summarise
      summary_field_count = group_by ? group_by.arity : 0

      rowmap = { }
      rows = []
      query_count = @query_group.size
      first = true
      for q in @query_group do
        sql_each_row_for_query(q.summary_query, *q.values) do |row|
          srow = nil
          if group_by then
            srow = SummaryRow.new(self,
              row[1 .. summary_field_count],
              row[0],
              @q.extra,
              row[(summary_field_count + 1)..-1])
          else
            srow = SummaryRow.new(self, nil, nil, @q.extra, row)
          end

          if query_count > 1
            filter_key = srow.key.to_s.downcase
            if first
              rowmap[filter_key] = srow
            else
              existing = rowmap[filter_key]
              existing.combine!(srow) if existing
            end
          else
            rows << srow
          end
        end
        first = false
      end

      raw_values = query_count > 1 ? rowmap.values : rows

      if query_count > 1
        raw_values.each do |rv|
          rv.extend!(query_count)
        end
      end

      filter = @query_group.filter
      STDERR.puts("Query group filters: #{filter}")
      if filter
        raw_values = raw_values.find_all do |row|
          filter.filter_value(@extra, row)
        end
      end

      if summary_field_count > 1
        raw_values = SummaryRowGroup.new(self).unify(raw_values)
      else
        raw_values = SummaryRowGroup.new(self).sort(raw_values)
      end

      @sorted_row_values = raw_values
      if filter
        @counts = count_filtered_values(@sorted_row_values)
      end
    end

    def count_filtered_values(sorted_summary_row_values)
      counts = [0, 0]
      for summary_row_value in sorted_summary_row_values
        if summary_row_value.counts
          row_count = summary_row_value.counts
          counts[0] += row_count[0]
          if row_count.size == 2
            counts[1] += row_count[1]
          end
        end
      end
      return counts[1] == 0 ? [counts[0]] : counts
    end
  end
end
