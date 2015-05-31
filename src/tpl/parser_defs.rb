require 'grammar/command_line'
require 'query/listgame_parser'
require 'sqlhelper'

module Tpl
  FunctionDef.define('text/cmdline', 1) {
    Grammar::CommandLineBuilder.build(self[0].to_s)
  }

  FunctionDef.define('lg/parse-cmd', [1, 3]) {
    nargs = self.arity
    nick = nargs >= 2 ? self[1].to_s : (scope['nick'] || '?')
    force_context = nargs >= 3 ? self[2] : true
    Query::ListgameParser.parse(nick, self[0].to_s, force_context)
  }
end
