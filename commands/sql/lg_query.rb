require 'sql/query_string'

module Sql
  class LgQuery
    def initialize(nick, argument_string, extra_args, context=CTX_LOG)
      @default_nick = nick
      @query_string = QueryString.new(argument_string)
      @options = @query.extract_options!('log', 'ttyrec')
      @context = context
      self.parse_query
    end

    # Is this a ratio X / Y query?
    def compound_query?
       @split_query_strings.size > 1
    end

    def summary?
      @primary_query.summarise?
    end

    def has_sorts?
      !@sorts.empty?
    end

    def has_extra?
      @extra_fields.empty?
    end

    def compound_query_needs_sort?
      compound_query? && !has_sorts?
    end

    # An X / Y query that is not a summary query and does not state what
    # field value it wants must default to the count of games.
    def compound_query_needs_content_field?
      compound_query? && !summary? && !has_extra?
    end

    def parse_query
      @extra_fields = self.parse_extra_field_clause()
      @sorts = self.parse_sort_fields()
      @group_filters = self.parse_group_filters()

      @split_query_strings = self.split_queries()
      @primary_query_string = @split_queries[0]

      if compound_query_needs_sort?
        @sorts = self.parse_sort_fields(QueryString.new("o=%"))
      end

      @nick = self.resolve_nick(@primary_query)

      self.build_primary_query
      self.build_query_list
    end

    def build_primary_query
      @primary_query =
        QueryBuilder.build(@nick, @primary_query_string,
                           @context, @extra_fields, false)

      # Not all split queries will have an aggregate column. For
      # instance: !lg * / win has no aggregate column, but the user
      # presumably wants to use counts. In such cases, add x=n for the
      # user.
      if compound_query_needs_content_field?
        @extra_fields = self.parse_extra_field_clause(QueryString.new("x=n"))
        @primary_query = QueryBuilder.build(@nick, @primary_query_string,
                                            @context, @extra_fields, false)
      end

      if summary? && !has_sorts?
        if has_extra?
          @sorts = @extra_fields.default_sorts
        else
          summary_field_list = @primary_query.summarise
          sort_field = summary_field_list.fields[0]
          @sorts = self.parse_sort_fields(
            QueryString.new("o=#{sort_field.order}n"))
        end
      end
    end

    def build_query_list

    end
  end
end
