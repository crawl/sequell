require 'sql/function_def'
require 'sql/errors'

module Sql
  class FunctionDefs
    def initialize(functions)
      @functions = functions
    end

    def function_defs
      @function_defs ||= Hash[ @functions.map { |name, fdef|
          [name, Sql::FunctionDef.new(name, fdef)]
        } ]
    end

    def [](name)
      self.function(name)
    end

    def function(function_name)
      if function_name =~ /^trunc(\d+)$/
        truncate_slab = $1.to_i
        if truncate_slab < 100
          raise UnknownFunctionError.new(function_name)
        end
        self.function_defs[function_name] =
          Sql::FunctionDef.truncate(function_name, truncate_slab)
      end
      self.function_defs[function_name]
    end

    def function_type(function_name)
      function_property(function_name, :type)
    end

    def function_expr(function_name)
      function_property(function_name, :expr)
    end

    def function_property(function_name, prop)
      function = self.function(function_name.downcase)
      raise UnknownFunctionError.new(function_name) unless function
      function.send(prop)
    end
  end
end
