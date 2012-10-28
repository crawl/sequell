module Query
  class SortFieldParser
    # Parses sort expressions (o=x) in the context of any extra-field
    # expression
    def self.parse(query_string, extra_fields, context)
      self.new(query_string, extra_fields, context).parse
    end

    def initialize(query_string, extra_fields, context)
      @query = query_string
      @context = context
      @extra = extra_fields
    end

    def sort_pattern
      %r/o=(\S+)/
    end

    def parse
      args = @query.args
      sort_match = args.find { |x| x =~ sort_pattern }
      sorts = []
      if sort_match
        @query.args = args.find_all { |x| x != sort_match }
        sorts = parse_sort_fields(sort_match)
      end
      sorts
    end

    def parse_sort_fields(sort_match)
      raise "Bad sort field #{sort_match}" unless sort_match =~ sort_pattern
      $1.split(',').map { |f| @extra.parse_sort_expr(f) }
    end
  end
end
