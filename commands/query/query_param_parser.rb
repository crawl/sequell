require 'query/query_struct'
require 'query/sort'
require 'query/query_expr_parser'
require 'sql/query_context'

module Query
  class QueryParamParser
    # Parses an argument list of listgame query parameters, returning
    # a QueryStruct
    def self.parse(query_string)
      self.new(query_string).parse
    end

    def initialize(query)
      @query = query
      @args = @query.args
    end

    def parse
      struct = QueryStruct.new
      parse_groups(struct, @args)
      unless struct.has_sorts?
        context = Sql::QueryContext.context
        struct.sort(Query::Sort.new(context.defsort))
      end
      struct
    end

    # Examines args for | operators at the top level and returns the
    # positions of all such.
    def split_or_clauses(args)
      level = 0
      i = 0
      or_positions = []
      while i < args.length
        arg = args[i]
        if arg == BOOLEAN_OR && level == 0
          or_positions << i
        end
        if arg == OPEN_PAREN
          level += 1
        elsif arg == CLOSE_PAREN
          level -= 1
          if level == -1
            or_positions << i
            return or_positions
          end
        end
        i += 1
      end
      or_positions << args.length unless or_positions.empty?
      or_positions
    end

    def parse_groups(predicates, args)
      # Check for top-level OR operators.
      or_operator_positions = self.split_or_clauses(args)
      if not or_operator_positions.empty?
        predicates.operator = 'OR'
        last = 0
        for i in or_operator_positions
          slice = args.slice(last, i - last)
          subpred = QueryStruct.new
          parse_groups(subpred, slice)
          predicates << subpred
          last = i + 1
        end
        return last
      end

      predicates.operator = 'AND'
      i = 0
      while i < args.length
        arg = args[i]
        i += 1
        return i if arg == CLOSE_PAREN
        if arg == OPEN_PAREN
          subpreds = QueryStruct.new
          i = parse_groups(subpreds, args[i .. -1]) + i
          predicates << subpreds
          next
        end
        predicates << parse_param(arg)
      end
    end

    def parse_param(arg)
      QueryExprParser.parse(arg)
    end
  end
end
