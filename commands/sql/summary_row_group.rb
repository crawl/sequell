require 'sql/summary_row'

module Sql
  class SummaryRowGroup
    def initialize(summary_reporter)
      @summary_reporter = summary_reporter
    end

    def sort(summary_rows)
      sorts = @summary_reporter.query_group.sorts
      #puts "Sorts: #{sorts}"
      sort_condition_exists = sorts && !sorts.empty? ? sorts[0] : nil
      if sort_condition_exists
        summary_rows.sort do |a,b|
          cmp = 0
          for sort in sorts do
            cmp = sort.sort_cmp(a, b)
            break if cmp != 0
          end
          cmp
        end
      else
        summary_rows.sort
      end
    end

    def unify(summary_rows)
      summary_field_list = @summary_reporter.query_group.primary_query.summarise
      field_count = summary_field_list.fields.size
      unify_groups(summary_field_list, 0, field_count, summary_rows)
    end

    def canonical_bucket_key(key)
      key.is_a?(String) ? key.downcase : key
    end

    def unify_groups(summary_field_list, which_group, total_groups, rows)
      current_field_spec = summary_field_list.fields[which_group]
      if which_group == total_groups - 1
        subrows = rows.map { |r|
          SummaryRow.subrow_from_fullrow(r, r.fields[-1])
        }
        subrows.each do |r|
          r.summary_field_spec = current_field_spec
        end
        return sort(subrows)
      end

      group_buckets = Hash.new do |hash, key|
        hash[key] = []
      end

      for row in rows
        group_buckets[canonical_bucket_key(row.fields[which_group])] << row
      end

      # Each bucket corresponds to a new SummaryRow that contains all its
      # children, unified:
      return sort(group_buckets.keys.map { |bucket_key|
          bucket_subrows = group_buckets[bucket_key]
          row = SummaryRow.subrow_from_fullrow(
            bucket_subrows[0],
            bucket_subrows[0].fields[which_group],
            unify_groups(summary_field_list,
              which_group + 1,
              total_groups,
              bucket_subrows))
          row.summary_field_spec = current_field_spec
          row
        })
    end
  end
end
