module Sql
  class QueryBuilder
    def self.build(nick, query_string, context, extra_fields,
                   extract_nick_from_query=false)
      self.new(nick, query_string, context, extra_fields,
               extract_nick_from_query).build
    end

    def initialize(nick, query_string, context, extra_fields,
                   extract_nick_from_query)
      @nick = nick
      @query_string = @query_string
      @context = context
      @extra_fields = extra_fields
      @extract_nick_from_query = extract_nick_from_query
    end

    def build
    end
  end
end
