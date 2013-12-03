# Hash-like object that provides the scope to evaluate a Sequell
# template AST (variable name -> value bindings).
module Tpl
  class BindingError < ::StandardError
    def initialize(key, val)
      @key = key
      @val = val
      super("Cannot rebind #{@key} to #{@val}")
    end
  end

  class Scope
    def self.wrap(scopelike={}, *delegates)
      return scopelike if scopelike.is_a?(self) && delegates.empty?
      self.new(scopelike, *delegates) if self.mutable_scope?(scopelike)
      self.new({ }, scopelike, *delegates)
    end

    def self.block(&block)
      self.new({ }, block)
    end

    def self.mutable_scope?(scopelike)
      scopelike.respond_to?(:[]) && scopelike.respond_to?(:[]=) &&
        scopelike.respond_to?(:include?)
    end

    def initialize(dict, *delegates)
      @dict = dict || { }
      @delegates = delegates.compact
    end

    def [](key)
      return @dict[key] if @dict.include?(key)
      delegate_lookup(key)
    end

    def []=(key, val)
      @dict[key] = val
    end

    def bound?(key)
      @dict.include?(key)
    end

    def rebind(key, val)
      if bound?(key)
        self[key] = val
      else
        delegates.each { |d|
          return d.rebind(key, val) if d.respond_to?(:rebind)
        }
        raise BindingError.new(key, val)
      end
    end

    def to_s
      "#{self.class}(#{@dict} / #{@delegates})"
    end

  protected
    def delegate_lookup(key)
      @delegates.each { |d|
        res = d[key]
        return res if res
      }
      nil
    end
  end

  class LazyEvalScope < Scope
    def initialize(raw, scope)
      super({ }, scope)
      @raw = raw
      @scope = scope
    end

    def [](key)
      return @dict[key] if @dict.include?(key)
      if @raw.include?(key)
        @dict[key] ||= eval_tpl(@raw[key], @scope)
      else
        delegate_lookup(key)
      end
    end

    def eval_tpl(tpl, scope)
      return tpl.eval(scope) if tpl.respond_to?(:tpl?)
      tpl
    end

    def bound?(key)
      @raw.include?(key) || @dict.include?(key)
    end
  end
end
