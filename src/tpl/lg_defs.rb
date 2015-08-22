module Tpl
  FunctionDef.define('lg/ast-context', 1) {
    self[0].context_name
  }

  FunctionDef.define('lg/ast-head', 1) {
    self[0].head
  }

  FunctionDef.define('lg/ast-tail', 1) {
    self[0].tail
  }

  FunctionDef.define('lg/ast-number', 1) {
    self[0].game_number
  }

  FunctionDef.define('lg/ast-nick', 1) {
    self[0].nick
  }

  FunctionDef.define('lg/ast-default-nick', 1) {
    self[0].default_nick
  }

  FunctionDef.define('lg/ast-order', 1) {
    ord = self[0].order
    ord.empty? ? nil : ord
  }

  FunctionDef.define('lg/ast-summarise', 1) {
    self[0].summarise
  }

  FunctionDef.define('lg/ast-extra', 1) {
    self[0].extra
  }

  FunctionDef.define('lg/ast-options', 1) {
    self[0].options
  }

  FunctionDef.define('lg/ast-keys', 1) {
    self[0].keys
  }
end
