module Query
  class QueryTemplateProperties
    def self.properties(ast)
      {
        'target' => ast.target_nick,
        'user' => ast.default_nick,
        'name' => ast.real_nick
      }
    end
  end
end
