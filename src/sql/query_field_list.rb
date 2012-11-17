require 'sql/query_sort_condition'
require 'sql/query_field'
require 'sql/field_expr_parser'
require 'sql/errors'

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
      field = parse_field(f)
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

    def parse_field(field)
      begin
        simple_field(field)
      rescue Sql::ParseError
        if field =~ /^(\w+)\((\S+)\)$/
          aggregate_function($1, $2)
        else
          raise
        end
      end
    end

    def simple_field(field)
      field = field.downcase.strip
      case field
      when 'n'
        return QueryField.new(self, 'COUNT(*)', nil, 'N',
          "count_" + QueryFieldList::unique_id())
      when '%'
        return QueryField.new(self, 'COUNT(*)', nil, '%',
          "count_" + QueryFieldList::unique_id(),
          :percentage)
      else
        @ctx.with do
          query_field = Sql::QueryField.new(self, nil, field, field)
          unless query_field.known?
            raise Sql::UnknownFieldError.new(query_field)
          end
          query_field
        end
      end
    end

    def aggregate_typematch(function, field)
      return function && field.type_match?(function.type)
    end

    def aggregate_function(func, field)
      @ctx.with do
        field = Sql::FieldExprParser.expr(field)
      end
      func = canonicalise_aggregate(func)

      # And check that the types match up.
      if not aggregate_typematch(func, field)
        raise "#{func} cannot be applied to #{field}"
      end

      fieldalias = (func.to_s + "_" + field.to_s.gsub(/[^\w]+/, '_') +
                    QueryFieldList::unique_id())

      fieldexpr = func.expr
      qf = QueryField.new(self, fieldexpr, field,
                          "#{func}(#{field})", fieldalias)
      qf.function = func
      qf
    end

    def canonicalise_aggregate(func)
      func = func.strip.downcase
      func_def = SQL_CONFIG.aggregate_functions.function(func)
      if not func_def
        raise "Unknown aggregate function #{func} in #{extra}"
      end
      func_def
    end
  end
end
