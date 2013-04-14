module Tpl
  class FunctionDef
    REGISTRY = { }
    def self.define(name, arity=1, &evaluator)
      REGISTRY[name] = self.new(name, evaluator, arity)
    end

    def self.evaluator(name)
      REGISTRY[name]
    end

    attr_reader :executor
    def initialize(name, evaluator, arity)
      @name = name
      @supported_arity = arity
      (class << self; self; end).send(:define_method, :eval, &evaluator)
    end

    def arguments
      @executor.arguments
    end

    def arity
      @executor.arity
    end

    def raw_arg(index)
      @executor.raw_arg(index)
    end

    def provider
      @executor.provider
    end

    def [](index)
      @cache[index] ||= @executor[index]
    end

    def autosplit(word, split_by=nil)
      return [] unless word
      return word if word.is_a?(Array)
      (if split_by
         word.split(split_by)
       elsif word.index('|')
         word.split('|')
       else
         word.split(',')
       end).map(&:strip)
    end

    def arity_match?
      @supported_arity == 0 || arity == @supported_arity ||
        (@supported_arity.is_a?(Array) && @supported_arity.include?(arity))
    end

    def eval_with(executor)
      @cache = { }
      @executor = executor
      unless arity_match?
        raise "Bad number of arguments to #{@name}, must be #{@supported_arity}"
      end
      return @executor.to_s unless self[-1]
      eval
    end
  end
end
