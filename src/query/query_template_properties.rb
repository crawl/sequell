module Query
  class QueryTemplateProperties
    def initialize(ast)
      @ast = ast
    end

    def [](key)
      case key
      when 'target'
        @ast.target_nick
      when 'user'
        @ast.default_nick
      when 'name'
        @ast.real_nick
      else
        nil
      end
    end
  end
end
