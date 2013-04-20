require 'henzell/config'
require 'tpl/function_def'
require 'command_context'

module Tpl
  FunctionDef.define('apply', [2,-1]) {
    arglist = self.raw_args[1 .. -2].dup
    Funcall.new(self[0], *(arglist + autosplit(self[-1]).to_a)).eval(scope)
  }

  FunctionDef.define('sort', [1,2]) {
    thing_to_sort = autosplit(self[-1])
    if arity == 1
      thing_to_sort.sort
    else
      funcall = Funcall.new(self[0])
      thing_to_sort.sort { |a, b|
        funcall.call(scope, a, b)
      }
    end
  }

  FunctionDef.define('inc', 1) { self[0] + 1 }
  FunctionDef.define('dec', 1) { self[0] - 1 }
  FunctionDef.define('value', 1) {
    val = self[0]
    val.is_a?(String) ? scope[val] : val
  }

  FunctionDef.define('call', [1, -1]) {
    arglist = self.raw_args[1..-1].dup
    Funcall.new(self[0], *arglist).eval(scope)
  }

  FunctionDef.define('hash', -1) {
    res = { }
    (0 ... self.raw_args.size).step(2).each { |i|
      res[self[i]] = self[i + 1]
    }
    res
  }

  FunctionDef.define('hash-put', [1, -1]) {
    res = self[-1].dup
    (0 ... (self.raw_args.size - 1)).step(2).each { |i|
      res[self[i]] = self[i + 1]
    }
    res
  }

  FunctionDef.define('elt', 2) {
    self[-1][self[0]]
  }

  FunctionDef.define('elts', [2, -1]) {
    indexable = self[-1]
    (0...(self.raw_args.size - 1)).map { |i|
      indexable[self[i]]
    }
  }

  FunctionDef.define('cons', [0,2]) {
    case arity
    when 0
      []
    when 1
      [self[0]]
    when 2
      [self[0]] + autosplit(self[-1]).to_a
    end
  }

  FunctionDef.define('typeof', 1) { self[0].class.to_s }

  FunctionDef.define('list', -1) {
    self.arguments.dup
  }

  FunctionDef.define('flatten', [1,2]) {
    if arity == 1
      autosplit(self[-1]).flatten
    else
      autosplit(self[-1]).flatten(self[0])
    end
  }

  FunctionDef.define('reverse', 1) {
    val = self[0]
    if val.is_a?(Hash)
      val.invert
    else
      val = val.to_a if val.is_a?(Enumerable)
      val.reverse
    end
  }

  FunctionDef.define('range', [2, 3]) {
    low = self[0].to_i
    high = self[1].to_i
    step = arity == 3 ? self[2].to_i : 1
    Range.new(low, high).step(step)
  }

  FunctionDef.define('concat', -1) {
    if arity == 0
      nil
    else
      self.arguments.reduce { |a, b|
        if a.is_a?(Hash)
          a.merge(b)
        elsif a.is_a?(String) || a.is_a?(Numeric)
          a.to_s + b.to_s
        else
          a.to_a + b.to_a
        end
      }
    end
  }

  FunctionDef.define('=', -1) {
    if arity <= 1
      true
    else
      first = canonicalize(self[0])
      (1...arity).all? { |index|
        canonicalize(self[index]) == first
      }
    end
  }

  FunctionDef.define('+', -1) { reduce_numbers(0, &:+) }
  FunctionDef.define('-', -1) { reduce_numbers(&:-) }
  FunctionDef.define('*', -1) { reduce_numbers(1, &:*) }
  FunctionDef.define('/', -1) { reduce_numbers(&:/) }
  FunctionDef.define('mod', 2) { self[0].to_i % self[1].to_i }
  FunctionDef.define('**', 2) { self[0].to_f ** self[1].to_f }
  FunctionDef.define('str', [0, 1]) {
    Tpl::Template.string(self[0])
  }
  FunctionDef.define('int', 1) { self[0].to_i }
  FunctionDef.define('float', 1) { self[0].to_f }

  FunctionDef.define('and', -1) { lazy_all?(true) { |a| truthy?(a) } }
  FunctionDef.define('or', -1) { lazy_any?(false) { |a| truthy?(a) } }
  FunctionDef.define('not', 1) { !self[-1] }

  FunctionDef.define('/=', 2) {
    canonicalize(self[0]) != canonicalize(self[1])
  }
  FunctionDef.define('<', -1) {
    lazy_neighbour_all?(true, &:<)
  }
  FunctionDef.define('<=', -1) {
    lazy_neighbour_all?(true, &:<)
  }
  FunctionDef.define('<=>', 2) {
    self[0] <=> self[1]
  }
  FunctionDef.define('>', -1) {
    lazy_neighbour_all?(true, &:>)
  }
  FunctionDef.define('>=', -1) {
    lazy_neighbour_all?(true, &:>=)
  }

  FunctionDef.define('if', [2,3]) {
    check = self[0]
    if truthy?(check)
      self[1]
    elsif arity == 3
      self[2]
    else
      ''
    end
  }

  FunctionDef.define('map', 2) {
    mapper = FunctionDef.evaluator(self[0], scope)
    scope = self.scope
    autosplit(self[-1]).map { |part| mapper.call(scope, part) }
  }

  FunctionDef.define('filter', 2) {
    mapper = FunctionDef.evaluator(self[0], scope)
    scope = self.scope
    autosplit(self[-1]).filter { |part| mapper.call(scope, part) }
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
  FunctionDef.define('nth', 2) {
    autosplit(self[-1])[self[0]]
  }
  FunctionDef.define('car', 1) {
    autosplit(self[-1])[0]
  }
  FunctionDef.define('cdr', 1) {
    autosplit(self[-1])[1..-1]
  }

  FunctionDef.define('rand', [1, 2]) {
    if arity == 2
      rand(self[0].to_i .. self[1].to_i)
    else
      rand(self[0].to_i)
    end
  }
end
