module Query
  module AST
    class FilterTerm < Term
      def self.term(term)
        self.new(term)
      end

      attr_reader :term
      def initialize(term)
        @term = term
      end

      def kind
        :filter_term
      end

      def ratio(num, den)
        num = num.to_f
        den = den.to_f
        den == 0 ? 0 : num / den
      end

      def filter_value(extra, row)
        unless @validated
          raise "Cannot get filter value for unvalidated field #{self}"
        end

        if @index.nil?
          bind_row_index!(extra)
          if row.counts && row.counts.size == 1
            @base_index = 0
          end
        end
        v = @binder.call(row)
        return v.downcase if v.is_a?(String)
        v
      end

      def find_extra_field_index(extra, expr)
        index = 0
        for ef in extra.fields do
          if ef.to_s == expr
            return index
          end
          index += 1
        end
        raise "Bad condition: #{expr}"
      end

      def bind_row_index!(extra)
        if @use_grouped_value
          @index = 0
        elsif term == 'n' || term == '%'
          @index = 1
        else
          @index = 2 + find_extra_field_index(extra, term)
        end

        if !@use_grouped_value
          @base_index = case @base
                        when 'den'
                          0
                        when 'num'
                          1
                        when '%'
                          2
                        else
                          1
                        end
        end

        if @use_grouped_value
          @binder = Proc.new { |r| r.compare_key }
        else
          extractor = if @base_index == 2
                        STDERR.puts("RATIO")
                        Proc.new { |v| v && ratio(v[1], v[0]) }
                      else
                        Proc.new { |v| v && v[@base_index] }
                      end

          if @index == 1
            @binder = Proc.new { |r| extractor.call(r.counts) }
          else
            index = @index - 2
            extra_field = extra.fields[index]
            @binder = Proc.new { |r|
              cv = extra_field.comparison_value(
                extractor.call(r.extra_values[index]))
              cv
            }
          end
        end
      end

      def validate_filter!(extra)
        field = term.to_s
        if field == '.'
          @use_grouped_value = true
        else
          field = "#{$1}%.n" if field =~ /^(-)?%$/
          if field =~ /^(den|num|%)[.](.*)/
            @base = $1
            field = $2
          end
          @term = field.downcase
          if term != 'n' && extra && extra.fields.any? { |x| x.to_s == term }
            raise "Bad sort condition: '#{field}'"
          end
        end
        @validated = true
      end

      def to_s
        term.to_s
      end
    end
  end
end
