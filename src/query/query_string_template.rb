module Query
  class QueryStringTemplate
    def self.substitute(query_string, argument_lists)
      argument_lists.reduce(query_string.to_s) { |query, arglist|
        substitute_query_args(query, arglist.strip)
      }
    end

    def self.substitute_query_args(query_string, arglist)
      args = arglist.split(' ')
      rest_args_used = false
      max_index = 0
      res =
        query_string.gsub(
        /\$(?:(\d+|\*)|\{\s*((?:\d+|\*)\s*(?::-[^\}]*?)?)\})/) {
        |match|
        placeholder = $1 || $2
        key, default_value = split_placeholder(placeholder)
        value = if key == '*'
                  rest_args_used = true
                  (args[max_index..-1] || []).join(' ')
                else
                  index = key.to_i
                  max_index = index if index > max_index
                  args[index - 1]
                end
        value = value.strip if value
        if value.nil? || value.empty?
          default_value
        else
          value
        end
      }
      if max_index == 0 && !rest_args_used && !arglist.empty?
        (QueryString.new(res) + arglist).to_s
      else
        res
      end
    end

    def self.split_placeholder(placeholder)
      if placeholder =~ /^(\d+|\*)\s*:-(.*)/
        [$1, $2]
      else
        [placeholder, '']
      end
    end
  end
end
