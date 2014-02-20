require 'henzell/config'
require 'tpl/function_def'
require 'tpl/scope'
require 'tpl/tplike'
require 'command_context'
require 'date'
require 'irc_color'

require 'tpl/learndb_fn_defs'
require 'tpl/re_fn_defs'

module Tpl
  FunctionDef.define('apply', [2, -1]) {
    arglist = self.raw_args[1 .. -2].dup
    Funcall.new(self[0], *(arglist + autosplit(self[-1]).to_a)).eval(scope)
  }

  FunctionDef.define('binding', [1, -1]) {
    binding = Scope.wrap(self[0] || { })
    nargs = self.arity
    (1 ... (nargs - 1)).each { |i|
      eval_arg(i, binding)
    }
    eval_arg(-1, binding) if nargs > 0
  }

  FunctionDef.define('bound?', 1) {
    !scope[self[0]].nil?
  }

  FunctionDef.define('call', [1, -1]) {
    arglist = self.raw_args[1..-1].dup
    Funcall.new(self[0], *arglist).eval(scope)
  }

  FunctionDef.define('dec', 1) { self[0] - 1 }

  FunctionDef.define('do', -1) {
    nargs = self.arity
    (0 ... (nargs - 1)).each { |i|
      self[i]
    }
    self[-1] if nargs > 0
  }

  FunctionDef.define('exec', 1) {
    command = self[0].to_s
    Cmd::Executor.execute_subcommand(command)
  }

  FunctionDef.define('with-nvl', [1, -1]) {
    nvl = self[0]
    nargs = self.arity
    Tpl::LookupFragment.with_nvl(nvl) {
      (1 ... (nargs - 1)).each { |i|
        self[i]
      }
      if nargs > 1
        self[-1]
      else
        Tpl::LookupFragment.nvl
      end
    }
  }

  FunctionDef.define('nvl', -1) {
    nargs = self.arity
    Tpl::LookupFragment.with_nvl('') {
      (0 ... (nargs - 1)).each { |i|
        self[i]
      }
      if nargs > 0
        self[-1]
      else
        Tpl::LookupFragment.nvl
      end
    }
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

  FunctionDef.define('eval', [1, 2]) {
    tpl = Tpl::Template.template(self[0])
    tpl.eval(arity == 2 ? self[-1] : scope)
  }

  FunctionDef.define('hash', -1) {
    res = { }
    (0 ... self.raw_args.size).step(2).each { |i|
      res[self[i]] = self[i + 1]
    }
    res
  }

  FunctionDef.define('hash-keys', 1) {
    self[0].keys
  }

  FunctionDef.define('hash-put', [1, -1]) {
    res = self[-1].dup
    (0 ... (self.raw_args.size - 1)).step(2).each { |i|
      res[self[i]] = self[i + 1]
    }
    res
  }

  FunctionDef.define('identity', 1) { self[0] }
  FunctionDef.define('inc', 1) { self[0] + 1 }

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

  FunctionDef.define('quote', 1) {
    raw_arg(0)
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

  FunctionDef.define('+', -1) { reduce_numbers(&:+) || 0 }
  FunctionDef.define('-', [1, -1]) {
    if arity == 1
      -self[0]
    else
      reduce_numbers(&:-)
    end
  }
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
  FunctionDef.define('not', 1) {
    !truthy?(self[-1])
  }

  FunctionDef.define('/=', 2) {
    canonicalize(self[0]) != canonicalize(self[1])
  }
  FunctionDef.define('<', -1) {
    lazy_neighbour_all?(true, &:<)
  }
  FunctionDef.define('<=', -1) {
    lazy_neighbour_all?(true, &:<=)
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

  FunctionDef.define('nick-aliases', 1) {
    nick_aliases(self[0])
  }

  FunctionDef.define('filter', 2) {
    mapper = FunctionDef.evaluator(self[0], scope)
    scope = self.scope
    autosplit(self[-1]).select { |part| mapper.call(scope, part) }
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

  FunctionDef.define('str-find', 2) {
    self[-1].to_s.index(self[0].to_s) || -1
  }

  FunctionDef.define('str-find?', 2) {
    self[-1].to_s.index(self[0].to_s) != nil
  }

  FunctionDef.define('replace', [2, 3]) {
    if arity == 2
      self[-1].to_s.gsub(self[0], '')
    else
      self[-1].to_s.gsub(self[0]) { self[1] }
    end
  }

  FunctionDef.define('replace-n', [3, 4]) {
    count = 0
    max = self[0].to_i
    if arity == 3
      self[-1].to_s.gsub(self[1]) { |m|
        count += 1
        if count > max && max != -1
          m
        else
          ''
        end
      }
    else
      self[-1].to_s.gsub(self[1]) { |m|
        count += 1
        if count > max && max != -1
          m
        else
          self[2]
        end
      }
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

  FunctionDef.define('time', 0) {
    DateTime.now
  }

  FunctionDef.define('utc', 1) {
    self[0].new_offset(0)
  }

  ISO8601_FMT = '%FT%T%z'

  FunctionDef.define('ptime', [1, 2]) {
    DateTime.strptime(self[0], arity == 2? self[-1] : ISO8601_FMT)
  }

  FunctionDef.define('ftime', [1, 2]) {
    self[0].strftime(arity == 2? self[-1] : ISO8601_FMT)
  }

  FunctionDef.define('interval-year', [0, 1]) {
    (arity == 1 ? self[-1] : 1) * 365
  }

  FunctionDef.define('interval-day', [0, 1]) {
    (arity == 1 ? self[-1] : 1)
  }

  FunctionDef.define('interval-day', [0, 1]) {
    (arity == 1 ? self[-1] : 1)
  }

  FunctionDef.define('interval-hour', [0, 1]) {
    (arity == 1 ? self[-1] : 1) * Rational(1, 24)
  }

  FunctionDef.define('interval-minute', [0, 1]) {
    (arity == 1 ? self[-1] : 1) * Rational(1, 24 * 60)
  }

  FunctionDef.define('interval-second', [0, 1]) {
    (arity == 1 ? self[-1] : 1) * Rational(1, 24 * 60 * 60)
  }

  FunctionDef.define('scope', [0, 1]) {
    if arity == 0
      scope
    else
      Scope.wrap(self[0], scope)
    end
  }

  FunctionDef.define('set!', -1) {
    s = self.scope
    res = nil
    (0 ... arity).step(2).each { |i|
      res = s.rebind(self[i], self[i + 1])
    }
    res
  }

  FunctionDef.define('sprintf', [1, -1]) {
    sprintf(self[0], *((1...arity).map { |x| self[x] }))
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

  FunctionDef.define('try', [1, 2]) {
    begin
      self[0]
    rescue StandardError => e
      arity == 2 ? eval_arg(-1, scope.subscope('err!' => e)) : nil
    end
  }

  FunctionDef.define('value', 1) {
    val = self[0]
    val.is_a?(String) ? scope[val] : val
  }

  FunctionDef.define('void', -1) { nil }

  FunctionDef.define('colour', [0, 2]) {
    nargs = self.arity
    case nargs
    when 0
      IRCColor.reset
    when 1
      IRCColor.color(self[0])
    when 2
      IRCColor.color(self[0], self[1])
    end
  }

  FunctionDef.define('coloured', [2, 3]) {
    text = self[-1]
    case arity
    when 2
      IRCColor.color(self[0]) + text + IRCColor.reset
    when 3
      IRCColor.color(self[0], self[1]) + text + IRCColor.reset
    end
  }
end
