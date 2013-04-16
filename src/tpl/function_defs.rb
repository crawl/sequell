require 'henzell/config'
require 'command_context'

module Tpl
  FunctionDef.define('map', 2) {
    mapper = self.raw_arg(0)
    prov = self.provider
    autosplit(self[-1]).map { |part|
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
      self[-1].to_s.gsub(self[0], '')
    else
      self[-1].to_s.gsub(self[0]) { self[1] }
    end
  }

  FunctionDef.define('upper', 1) { self[-1].to_s.upcase }
  FunctionDef.define('lower', 1) { self[-1].to_s.downcase }

  FunctionDef.define('length', 1) {
    val = self[-1]
    if val.is_a?(Array)
      val.size
    else
      val.to_s.size
    end
  }
  FunctionDef.define('sub', [2,3]) {
    val = self[-1]
    val = val.to_s unless val.is_a?(Array)
    if arity == 2
      val[self[0].to_i .. -1]
    else
      val[self[0].to_i ... self[1].to_i]
    end
  }
end
