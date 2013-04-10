module Query
  class QueryTemplateProperties
    def initialize(ast)
      @ast = ast
    end

    def [](key)
      STDERR.puts("Property requested: #{key}")
      case key
      when 'name'
        @ast.actual_nick
      when 'user'
        @ast.default_nick
      else
        nil
      end
    end
  end
end
