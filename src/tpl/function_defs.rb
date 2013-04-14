require 'henzell/config'
require 'command_context'

module Tpl
  FunctionDef.define('map', 2) {
    mapper = self.raw_arg(0)
    prov = self.provider
    autosplit(self[-1]).map { |part|
      STDERR.puts("mapper: #{mapper.inspect} (#{mapper.class})")
      mapper.eval(lambda { |key|
          if key == '_'
            part
          else
            prov[key]
          end
        })
    }
  }

  FunctionDef.define('join', [1,2]) {
    if arity == 1
      autosplit(self[-1]).join(CommandContext.default_join)
    else
      autosplit(self[-1]).join(self[0])
    end
  }

  FunctionDef.define('split', [1, 2]) {
    if arity == 1
      autosplit(self[-1], ',')
    else
      autosplit(self[-1], self[0])
    end
  }

  FunctionDef.define('replace', [2, 3]) {
    if arity == 2
      self[-1].gsub(self[0], '')
    else
      self[-1].gsub(self[0]) { self[1] }
    end
  }
end
