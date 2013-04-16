require 'tpl/function'

module Tpl
  class FunctionDef
    REGISTRY = { }
    def self.define(name, arity=1, &evaluator)
      REGISTRY[name] = self.new(name, evaluator, arity)
    end

    def self.evaluator(name, scope=nil)
      evaluator = name.is_a?(Function)? name : REGISTRY[name]
      if !evaluator && scope
        fdef = scope[name]
        self.new(name, fdef, fdef.arity) if fdef
      elsif evaluator.is_a?(Function)
        self.new(evaluator.name, evaluator, evaluator.arity)
      else
        evaluator && evaluator.dup
      end
    end

    attr_reader :executor
    def initialize(name, evaluator, arity)
      @name = name
      @evaluator = evaluator
      @supported_arity = arity
      @user_function = @evaluator.is_a?(Function)
      unless @user_function
        (class << self; self; end).send(:define_method, :eval, &evaluator)
      end
    end

    def user_function?
      @user_function
    end

    def dup
      self.class.new(@name, @evaluator, @supported_arity)
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
    alias :scope :provider

    def number_arguments
      self.arguments.map { |arg|
        arg.is_a?(String) ? (arg.index('.') ? arg.to_f : arg.to_i) : arg
      }
    end

    def reduce_numbers(identity=nil, &block)
      if identity
        self.number_arguments.reduce(identity, &block)
      else
        self.number_arguments.reduce(&block)
      end
    end

    def lazy_neighbour_all?(default)
      if arity <= 1
        default
      else
        last = self[0]
        (1...arity).all? { |index|
          curr = self[index]
          res = yield(last, curr)
          last = curr
          res
        }
      end
    end

    def [](index)
      @cache[index] ||= @executor[index]
    end

    def autosplit(word, split_by=nil)
      return [] unless word
      return word if word.is_a?(Array)
      word = word.to_s
      (if split_by
         word.split(split_by)
       elsif word.index('|')
         word.split('|')
       else
         word.split(',')
       end).map(&:strip)
    end

    def arity_match?
      @supported_arity == -1 || arity == @supported_arity ||
        (@supported_arity.is_a?(Array) &&
         (@supported_arity.include?(arity) ||
          @supported_arity[0] <= arity &&
           (@supported_arity[1] == -1 || @supported_arity[1] >= arity)))
    end

    def funcall
      @executor.funcall
    end

    def eval_with(executor)
      @cache = { }
      @executor = executor
      unless arity_match?
        raise "Bad number of arguments to #{@name}, must be #{@supported_arity}"
      end
      result = if user_function?
        eval_user_function
      else
        eval
      end
      result.nil? ? @executor.to_s : result
    end

    def evaluate(value, scope)
      return value.eval(scope) if value.respond_to?(:tpl?)
      value
    end

    def eval_user_function
      map = { }
      evaluated = { }
      fn = @evaluator
      fn.parameters.each_with_index { |p, i|
        map[p] = raw_arg(i)
      }
      map[fn.rest] = funcall.arguments[fn.parameters.size .. -1]
      dynamic_scope = lambda { |key|
        if map.include?(key)
          evaluated[key] ||= evaluate(map[key], scope)
        else
          scope[key]
        end
      }
      fn.body.eval(dynamic_scope)
    end
  end
end
