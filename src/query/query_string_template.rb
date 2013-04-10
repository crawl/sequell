module Query
  class QueryStringTemplate
    def self.substitute(query_string, argument_lists)
      argument_lists.reduce(query_string.to_s) { |query, arglist|
        substitute_query_args(query, arglist.strip)
      }
    end

    def self.substitute_query_args(query_string, arglist)
      require 'tpl/template'

      args = arglist.split(' ')
      rest_args_used = false
      max_index = 0

      arg_provider = lambda { |key|
        return nil unless key =~ /^\d+$/ || key == '*'
        if key == '*'
          rest_args_used = true
          (args[max_index..-1] || []).join(' ')
        else
          index = key.to_i
          max_index = index if index > max_index
          args[index - 1]
        end
      }
      res = Tpl::Template.template_eval(query_string, arg_provider)
      STDERR.puts("EXPAND #{query_string} => #{res}")
      if max_index == 0 && !rest_args_used && !arglist.empty?
        res.gsub(%r{(\?:.*)?$}, ' ' + arglist + ' \1')
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
