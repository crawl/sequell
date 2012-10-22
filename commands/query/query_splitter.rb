module Sql
  class QuerySplitter
    def self.apply(query_string)
      query = query_string.to_s
      if query =~ %r{(.*)/(.*)}
        args = [$1, $2].map { |x| x.strip }.find_all { |x| !x.empty? }
        return args.map { |x| QueryString.new(x, query_string.context) }
      end
      [ query_string ]
    end
  end
end
