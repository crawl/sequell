require 'query/nick'
require 'query/query_struct'
require 'query/query_param_parser'
require 'query/nick_expr'
require 'sql/crawl_query'

module Query
  class QueryParser
    def self.parse(nick, num, query_string, extra)
      self.new(nick, num, query_string, extra).parse
    end

    def initialize(nick, num, query_string, extra)
      @nick = nick
      @num = num
      @query_string = query_string
      @extra = extra
    end

    def parse
      @query_string.normalize!
      @body = QueryStruct.new
      self.parse_query_params
      Sql::CrawlQuery.new(@body, @body.sorts, @extra, @nick, @num,
                          self.argument_string)
    end

    def parse_query_params
      @body.append(self.nick_predicate) unless Query::Nick.any?(@nick)
      @query_string.normalize!
      @body.append(self.parse_query_param_groups)
    end

    def nick_predicate(nick=@nick, inverted=false)
      NickExpr.predicate(nick, inverted)
    end

    def parse_query_param_groups
      QueryParamParser.parse(@query_string)
    end

    def argument_string
      display_string = @query_string.display_string
      return @nick if display_string.empty?
      "#{@nick} (#{display_string})"
    end
  end
end
