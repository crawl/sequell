require 'sql/query_sort_condition'
require 'sql/query_field'

module Sql
  class QueryFieldList
    @@idbase = 0

    attr_accessor :fields, :extra
    def initialize(extra, ctx)
      extra = extra || ''
      @fields = []
      @ctx = ctx
      @extra = extra
      fields = extra.gsub(' ', '').split(',').find_all { |f| !f.empty? }
      fields.each do |f|
        @fields << parse_extra_field(f)
      end

      if not consistent?
        raise "Cannot mix aggregate and non-aggregate fields in #{extra}"
      end
      @aggregate = !@fields.empty?() && @fields[0].aggregate?()
    end

    def to_s
      "QueryFields:#{@fields.inspect}"
    end

    def parse_extra_field(f)
      order = '+'
      if f =~ /^([+-])/
        order = $1
        f = f[1 .. -1]
      end
      field = if f =~ /^(\w+)\((\w+)\)/
                aggregate_function($1, $2)
              else
                simple_field(f)
              end
      field.order = order
      field
    end

    def parse_sort_expr(expr)
      negated, expr = split_negated_expression(expr)
      QuerySortCondition.new(self, expr, negated)
    end

    def default_sorts
      @fields.map { |f| f.default_sort }
    end

    def empty?
      @fields.empty?
    end

    def aggregate?
      @aggregate
    end

    def self.unique_id()
      @@idbase += 1
      @@idbase.to_s
    end

    # Ensure that all fields are aggregate or that all fields are NOT aggregate.
    def consistent?
      return true if @fields.empty?
      aggregate = @fields[0].aggregate?
      return @fields.all? { |x| x.aggregate?() == aggregate }
    end

    def simple_field(field)
      field = field.downcase.strip
      if field == 'n'
        return QueryField.new(self, 'COUNT(*)', nil, 'N',
          "count_" + QueryFieldList::unique_id())
      elsif field == '%'
        return QueryField.new(self, 'COUNT(*)', nil, '%',
          "count_" + QueryFieldList::unique_id(),
          :percentage)
      end
      @ctx.with do
        return Sql::QueryField.new(self, nil, Sql::Field.field(field), field)
      end
    end

    def aggregate_typematch(func, field)
      ftype = SQL_CONFIG.aggregate_function_types[func]
      return ftype == '*' || ftype == @ctx.field_type(field)
    end

    def aggregate_function(func, field)
      @ctx.with do
        field = Sql::Field.field(field)
      end
      func = canonicalise_aggregate(func)

      # And check that the types match up.
      if not aggregate_typematch(func, field)
        raise "#{func} cannot be applied to #{field}"
      end

      fieldalias = (func + "_" + field.name.gsub(/[^\w]+/, '_') +
        QueryFieldList::unique_id())

      fieldexpr = "#{func}(%s)"
      fieldexpr = "COUNT(DISTINCT %s)" if func == 'cdist' || func == 'count'
      return QueryField.new(self, fieldexpr, field,
        "#{func}(#{field})", fieldalias)
    end

    def canonicalise_aggregate(func)
      func = func.strip.downcase
      if not SQL_CONFIG.aggregate_function_types[func]
        raise "Unknown aggregate function #{func} in #{extra}"
      end
      func
    end
  end
end
