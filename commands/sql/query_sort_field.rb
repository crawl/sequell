require 'date'

module Sql
  class QuerySortField
    def initialize(field, extra)
      @field = field
      @extra = extra
      parse_field_spec
    end

    def ratio(num, den)
      num = num.to_f
      den = den.to_f
      den == 0 ? 0 : num / den
    end

    def to_s
      @field
    end

    def value(row)
      if @index.nil?
        bind_row_index!
        if row.counts && row.counts.size == 1
          @base_index = 0
        end
      end
      v = @binder.call(row)
      return Sql::Date.display_date(v) if v.is_a?(DateTime)
      v
    end

    def find_extra_field_index(expr)
      index = 0
      for ef in @extra.fields do
        if ef.display == expr
          return index
        end
        index += 1
      end
      return nil
    end

    def bind_row_index!
      if @value
        @index = 0
      elsif @expr == 'n'
        @index = 1
      else
        @index = 2 + find_extra_field_index(@expr)
      end

      if !@value
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

      if @value
        @binder = Proc.new { |r| r.key }
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
          @binder = Proc.new { |r| extractor.call(r.extra_values[index]) }
        end
      end
    end

    def parse_field_spec
      field = @field
      if field == '.'
        @value = true
      else
        field = "#{$1}%.n" if field =~ /^(-)?%$/
        if field =~ /^(den|num|%)[.](.*)/
          @base = $1
          field = $2
        end
        @expr = field.downcase
        if @expr != 'n' && !@extra.fields.any? { |x| x.display == @expr }
          raise "Bad sort condition: '#{field}'"
        end
      end
    end
  end
end
