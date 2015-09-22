module Query
  class QueryTemplateProperties
    def self.properties(ast)
      {
        'target' => ast.target_nick,
        'user' => ast.default_nick,
        'name' => ast.real_nick,
        'cmd' => ast.description(ast.real_nick, context: true, meta: true,
                                 tail: true, no_parens: true)
      }
    end
  end
end
