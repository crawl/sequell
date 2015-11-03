require 'tpl/function'
require 'tpl/scope'
require 'cmd/user_function'

module Tpl
  class FunctionValue
    def self.value(fvalue)
      return nil unless fvalue
      return fvalue if fvalue.is_a?(self)
      self.new(fvalue.name)
    end

    attr_reader :name
    def initialize(name)
      @name = name
    end

    def to_s
      "#fn:#{@name}"
    end
  end

  class FunctionDef
    REGISTRY = { }
    def self.define(name, arity=1, &evaluator)
      REGISTRY[name] = self.new(name, evaluator, arity)
    end

    def self.scope(inner, outer=nil)
      Scope.wrap(inner, outer)
    end

    def self.callable?(thing)
      thing.is_a?(Function) || thing.is_a?(self)
    end

    def self.find_definition(name, scope)
      scope_def = scope && scope[name]
      scope_def = nil if scope_def.is_a?(FunctionValue) || scope_def.is_a?(String)
      scope_def ||
        ::Cmd::UserFunction.function_definition(name) ||
        REGISTRY[name]
    end

    def self.global_function_value(name)
      ::Cmd::UserFunction.function_definition(name) ||
        FunctionValue.value(REGISTRY[name])
    end

    def self.evaluator(name, scope=nil)
      return name if name.is_a?(self)
      name = name.name if name.is_a?(FunctionValue)
      evaluator_for(name.is_a?(Function)? name : find_definition(name, scope))
    end

    def self.evaluator_for(function_def)
      return nil unless function_def
      if function_def.is_a?(Function)
        self.new(function_def.name, function_def, function_def.arity)
      elsif function_def.is_a?(self)
        function_def && function_def.dup
      else
        raise "Invalid function def: #{function_def} (#{function_def.class})"
      end
    end

    def self.builtin?(name)
      fdef = find_definition(name, nil)
      fdef && !fdef.is_a?(Function)
    end

    attr_reader :name, :executor, :evaluator
    def initialize(name, evaluator, arity)
      @name = name
      @evaluator = evaluator
      @supported_arity = arity
      @user_function = @evaluator.is_a?(Function)
    end

    def builtin?
      !user_function?
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

    def raw_args
      @executor.raw_args
    end

    def provider
      @executor.scope
    end
    alias :scope :provider

    def number(arg)
      arg.is_a?(String) ? (arg.index('.') ? arg.to_f : arg.to_i) : arg
    end

    def truthy?(val)
      val && val != 0 && (!val.respond_to?(:empty?) || !val.empty?)
    end

    def number_arguments
      self.arguments.map { |arg|
        number(arg)
      }
    end

    def reduce_numbers(identity=nil, &block)
      if identity
        self.number_arguments.reduce(identity, &block)
      else
        self.number_arguments.reduce(&block)
      end
    end

    def lazy_all?(default)
      if arity == 0
        default
      else
        val = nil
        (0...arity).each { |index|
          val = self[index]
          res = yield(val)
          return val unless res
        }
        val
      end
    end

    def lazy_any?(default)
      if arity == 0
        default
      else
        val = nil
        (0...arity).each { |index|
          val = self[index]
          res = yield(val)
          return val if res
        }
        val
      end
    end

    def lazy_neighbour_all?(default)
      if arity <= 1
        default
      else
        last = self[0]
        (1...arity).all? { |index|
          curr = self[index]
          if last.kind_of?(Numeric) || curr.kind_of?(Numeric)
            last = number(last)
            curr = number(curr)
          end
          res = yield(last, curr)
          last = curr
          res
        }
      end
    end

    def [](index)
      @cache[index] ||= @executor[index]
    end

    def eval_arg(index, override_scope={})
      @executor.eval_arg(index, override_scope)
    end

    def canonicalize(val)
      val.is_a?(Enumerable) ? val.to_a : val
    end

    ##
    # autosplit converts word into an Array, by calling to_a, or stringifying
    # and splitting it
    def autosplit(word, split_by=nil)
      return [] unless word
      return word.to_a if word.is_a?(Enumerable)
      word = word.to_s
      (if split_by
         word.split(split_by)
       elsif word.index('|')
         word.split('|')
       else
         word.split(/[, ]/)
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

    def call(scope, *args)
      Funcall.new(self, *args).eval(scope)
    end

    def eval(scope)
      self
    end

    def eval_with(executor)
      @cache = { }
      @executor = executor
      unless arity_match?
        raise "Bad number of arguments (#{arity}) to #{@name || @evaluator}, must be #{@supported_arity}"
      end
      result = if user_function?
        eval_user_function
      else
        instance_exec(&@evaluator)
      end
      result
    end

    def eval_user_function
      map = { }
      fn = @evaluator
      fn.parameters.each_with_index { |p, i|
        map[p] = raw_arg(i)
      }
      map[fn.rest] = funcall.arguments[fn.parameters.size .. -1]
      map[fn.name] = fn if fn.name
      dynamic_scope = LazyEvalScope.new(map, scope)
      fn.eval_body_in_scope(dynamic_scope)
    end

    def to_s
      return @evaluator.to_s if user_function?
      @name.to_s
    end
  end
end
