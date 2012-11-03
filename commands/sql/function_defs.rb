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

    def function(function_name)
      self.function_defs[function_name]
    end

    def function_type(function_name)
      function_property(function_name, :type)
    end

    def function_expr(function_name)
      function_property(function_name, :expr)
    end

    def function_property(function_name, prop)
      function = self.function_defs[function_name.downcase]
      raise UnknownFunctionError.new(function_name) unless function
      function.send(prop)
    end
  end
end
