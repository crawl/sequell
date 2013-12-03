require 'tpl/scope'

module Query
  class QueryStringTemplate
    def self.substitute(query_string, argument_lists, scope={})
      argument_lists.reduce(query_string.to_s) { |query, arglist|
        expand(query, arglist.strip, scope)
      }
     end

    def self.expand(query_string, arglist, scope={})
      require 'tpl/template'

      args = arglist.split(' ')
      rest_args_used = false
      max_index = 0

      arg_provider = Tpl::Scope.block { |key|
        case key
        when '*'
          rest_args_used = true
          (args[max_index..-1] || []).join(' ')
        when /^\d+$/
          index = key.to_i
          max_index = index if index > max_index
          args[index - 1] || ''
        else
          scope[key]
        end
      }
      res = Tpl::Template.template_eval_string(query_string, arg_provider)
      if max_index == 0 && !rest_args_used && !arglist.empty?
        res.gsub(%r{(\?:.*)?$}, ' ' + arglist + ' \1')
      else
        res
      end
    end
  end
end
