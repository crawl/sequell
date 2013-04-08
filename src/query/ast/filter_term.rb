module Query
  module AST
    class FilterTerm < Term
      def self.term(term, options={})
        return term if term.is_a?(self)
        self.new(term, options)
      end

      attr_reader :term
      def initialize(term, options={})
        @term = term
        @denominator = options[:denominator]
        @ratio = options[:ratio] || @term == '%'
        @term = 'n' if @term == '%'
      end

      def ratio?
        @ratio
      end

      def numerator?
        !denominator?
      end

      def denominator?
        @denominator
      end

      def kind
        :filter_term
      end

      def ratio(num, den)
        num = num.to_f
        den = den.to_f
        den == 0 ? 0 : num / den
      end

      def filter_value(query, row)
        unless @validated
          raise "Cannot get filter value for unvalidated field #{self}"
        end

        if @index.nil?
          bind_row_index!(query.extra)
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
          if ef.to_s == expr.to_s
            return index
          end
          index += 1
        end
        raise "Bad condition: #{expr}"
      end

      def bind_row_index!(extra)
        if @use_grouped_value
          @index = 0
        elsif term == 'n' || term == 'N' || term == '%'
          @index = 1
        else
          @index = 2 + find_extra_field_index(extra, term)
        end

        if !@use_grouped_value
          @base_index = case
                        when ratio?
                          2
                        when denominator?
                          0
                        else
                          1
                        end
        end

        if @use_grouped_value
          @binder = Proc.new { |r| r.compare_key }
        else
          extractor = if @base_index == 2
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

      def validate_filter!(summarise, extra)
        if term.to_s == '.' || (summarise && term.to_s == summarise.first.to_s)
          @use_grouped_value = true
        else
          if term.to_s.downcase != 'n' &&
              (!extra || !extra.fields.any? { |x| x.to_s == term.to_s })
            raise "Bad sort condition: '#{self}' (extra: #{extra})"
          end
        end
        @validated = true
      end

      def qualifier
        return '%.' if ratio?
        return 'den.' if denominator?
        ''
      end

      def to_s
        qualifier + term.to_s
      end
    end
  end
end
