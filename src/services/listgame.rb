require 'sqlhelper'
require 'query/listgame_query'

module Services
  module Listgame
    class Query
      attr_reader :ctx, :params
      ##
      # Recognized query params:
      # - count (can also be in !lg query)
      # - order (same as min/max in query)
      # - nick (defaults to "*")
      # - q (explicit !lg query)
      def initialize(ctx, params)
        @ctx = ctx
        @params = params
      end

      def result
        ::Query::QueryExecutor.json(query.query_list)
      end

      def default_nick
        params[:nick] || '*'
      end

    private

      def query
        STDERR.puts("Running query: #{query_text}")
        @query ||= ::Query::ListgameQuery.parse(default_nick, query_text)
      end

      def query_text
        @query_text ||= QueryBuilder.new(ctx, params).build
      end
    end

    class QueryBuilder
      attr_reader :ctx, :params
      def initialize(ctx, params)
        @ctx = ctx
        @params = params
      end

      def build
        return params[:q] if params[:q]
        "#{ctx.name} #{params[:nick] || '*'}#{count_clause}#{index_clause}#{misc_clauses}"
      end

      def index_clause
        return "" unless params[:index].to_i != 0
        " #{params[:index].to_i}"
      end

      def count_clause
        return "" unless params[:count].to_i > 0
        " -count:#{params[:count].to_i}"
      end

      def misc_clauses
        ignored_keys = Set.new(['count', 'index', 'q'])
        res = params.keys.find_all { |k| !ignored_keys.include?(k) }.map { |k|
          "#{k.to_s}=#{params[k].to_s}"
        }.join(" ")
        return res if res.empty?
        " #{res}"
      end
    end
  end
end
