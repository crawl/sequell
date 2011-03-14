##
# Provides special-cases tied to individual query contexts.
class QueryContextFixups
  class QueryContextFixup
    attr_accessor :keyword_matchers, :field_fixups

    def initialize
      @keyword_matchers = []
      @field_fixups = []
    end

    def + (other)
      new_fixup = self.dup
      new_fixup.keyword_matchers += other.keyword_matchers
      new_fixup.field_fixups += other.field_fixups
      new_fixup
    end

    def keyword_transform(keyword)
      matches = []
      matcher_names = []
      @keyword_matchers.each do |keyword_matcher|
        expr = keyword_matcher.call(keyword)
        if expr
          matches << expr
          matcher_names << keyword_matcher.name
        end
      end
      if matcher_names.size > 1
        matchers = matcher_names.join(' or ')
        raise QueryError.new("Ambiguous keyword `#{keyword}` - " +
                             "may be #{matchers} (#{matches.join(' or ')})")
      end
      matches[0]
    end

    def field_transform(field_name, op, value)
      lower_field_name = field_name.downcase
      @field_fixups.each do |fixup|
        result = fixup.call(lower_field_name, op, value)
        return result if result
      end
      nil
    end
  end

  @@current_context_name = nil

  @@context_fixups = Hash.new do |hash, key|
    hash[key] = QueryContextFixup.new
  end

  def self.context(context_name)
    old_context_name = @@current_context_name
    @@current_context_name = context_name
    begin
      yield
    ensure
      @@current_context_name = old_context_name
    end
  end

  def self.bind_action_name(action_name, action)
    action.instance_variable_set(:@action_name, action_name)
    class << action
      def name
        @action_name
      end
    end
    action
  end

  def self.keyword_match(action_name, &action)
    bind_action_name(action_name, action)
    current_fixup.keyword_matchers << action
  end

  def self.field_match(action_name, &action)
    bind_action_name(action_name, action)
    current_fixup.field_fixups << action
  end

  def self.equal_op_block(&block)
    lambda do |field, op, value|
      if QueryConfig::Operators.equal_op?(op)
        block.call(field, op, value)
      end
    end
  end

  def self.op_block(operators, &block)
    unless operators.is_a?(Array)
      operators = [operators, QueryConfig::Operators.negate(operators)]
    else
      operators = Set.new(operators.map { |o|
                            [o, QueryConfig::Operators.negate(o)]
                          }.flatten)
    end
    Proc.new do |field, op, value|
      if operators.include?(op)
        block.call(field, op, value)
      end
    end
  end

  def self.field_equal_match(action_name, &block)
    self.field_match(action_name, &equal_op_block(&block))
  end

  def self.field_name_match(field_names, action_name=nil)
    field_names = [field_names] unless field_names.is_a?(Array)
    action_name = field_names.join('/') unless action_name
    self.field_match(action_name) do |field, op, value|
      if field_names.include?(field)
        yield(field, op, value)
      end
    end
  end

  def self.field_name_equal_match(field_names, action_name=nil, &block)
    self.field_name_match(field_names, action_name, &equal_op_block(&block))
  end

  def self.field_name_op_match(field_names, ops, action_name=nil, &block)
    self.field_name_match(field_names, action_name, &op_block(ops, &block))
  end

  def self.current_fixup
    unless @@current_context_name
      raise Exception.new("keyword_match must be registered within a context")
    end
    @@context_fixups[@@current_context_name]
  end

  def self.context_fixups(context_name)
    @@context_fixups[:any] + @@context_fixups[context_name]
  end

  context :any do
    field_equal_match('equal-to-regex') do |field, op, value|
      if value =~ /[()|?]/
        new_op = op == '=' ? '~~' : '!~~'
        SQLExprs.field_op_val(field, new_op, value)
      end
    end
  end
end

require 'commands/query_context_fixup_defs.rb'
