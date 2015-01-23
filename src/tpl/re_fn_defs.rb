require 're2'

class String
  def re2_gsub(re2_regexp, repl=nil)
    re2_regexp = RE2::Regexp.new(re2_regexp.to_s) if re2_regexp.is_a?(String)
    pos = 0
    len = self.size
    fragments = []
    new_string = ''
    substr = self[pos, len]
    while true
      match = re2_regexp.match(self, -1, pos)
      break unless match && (match.end(0) - match.begin(0)) > 0
      fragments << self[pos, match.begin(0) - pos]
      fragments << (repl ? repl : yield(match))
      pos = match.end(0)
    end
    fragments << (self[pos, self.size] || '')
    fragments.join('')
  end
end

module Tpl
  class RE2MatchWrapper
    def initialize(match)
      @match = match
    end

    def [](key)
      if key =~ /^\d+$/
        @match[key.to_i]
      else
        @match[key]
      end
    end
  end

  class RERepl
    def initialize(repl)
      @repl = Tpl::Template.template(repl)
      @fn = @repl.is_a?(Tpl::Function)
      @matcher_arg = @fn && @repl.arity_match?(1)
    end

    def invoke(scope, matcher)
      wrapped_scope = Scope.wrap(matcher, scope)
      if @fn
        if @matcher_arg
          @repl.call(wrapped_scope, matcher)
        else
          @repl.call(wrapped_scope)
        end
      else
        @repl.eval(wrapped_scope)
      end
    end
  end

  FunctionDef.define('re-find', [2, 3]) {
    re = self[0]
    re = RE2::Regexp.new(re.to_s) unless re.is_a?(RE2::Regexp)
    index = arity == 3 ? self[-1].to_i : 0
    re.match(self[1].to_s, -1, index)
  }

  FunctionDef.define('match-n', [1, 2]) {
    match = self[0]
    unless match.is_a?(RE2::MatchData)
      raise "Expected match object, got: #{match}"
    end
    match[ arity == 2 ? self[-1] : 0 ]
  }

  FunctionDef.define('match-groups', 1) {
    match = self[0]
    unless match.is_a?(RE2::MatchData)
      raise "Expected match object, got: #{match}"
    end
    match.to_a
  }

  FunctionDef.define('match-begin', [1, 2]) {
    match = self[0]
    group = arity == 2 ? self[-1].to_i : 0
    unless match.is_a?(RE2::MatchData)
      raise "Expected match object, got: #{match}"
    end
    match.begin(group)
  }

  FunctionDef.define('match-end', [1, 2]) {
    match = self[0]
    group = arity == 2 ? self[-1].to_i : 0
    unless match.is_a?(RE2::MatchData)
      raise "Expected match object, got: #{match}"
    end
    match.end(group)
  }

  FunctionDef.define('re-replace', [2, 3]) {
    if arity == 2
      self[-1].to_s.re2_gsub(self[0], '')
    else
      repl = RERepl.new(self[1])
      self[-1].to_s.re2_gsub(self[0]) { |m|
        repl.invoke(scope, RE2MatchWrapper.new(m))
      }
    end
  }

  FunctionDef.define('re-replace-n', [3, 4]) {
    count = 0
    max = self[0].to_i
    if arity == 3
      self[-1].to_s.re2_gsub(self[1]) { |m|
        count += 1
        if count > max && max != -1
          m.to_s
        else
          ''
        end
      }
    else
      repl = RERepl.new(self[2])
      self[-1].to_s.re2_gsub(self[1]) { |m|
        count += 1
        if count > max && max != -1
          m.to_s
        else
          repl.invoke(scope, RE2MatchWrapper.new(m))
        end
      }
    end
  }
end
