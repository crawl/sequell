class Treetop::Runtime::SyntaxNode
  attr_writer :elements
  attr_accessor :lg_node

  def flatten_tree()
    return QueryNode.new(self)
  end
end

class QueryNode
  def self.resolve_elements(children)
    return [] if children.nil?
    results = []
    for c in children
      resolved = self.resolve_node(c)
      next if resolved.nil?
      if resolved.is_a?(Array)
        results += resolved
      else
        results << resolved
      end
    end
    results
  end

  def self.resolve_node(syntax_node)
    value =
      if syntax_node.lg_node
        QueryNode.new(syntax_node)
      else
        children = self.resolve_elements(syntax_node.elements)
        if children.size == 1
          children[0]
        else
          children
        end
      end
    if (value.is_a?(QueryNode) &&
        value.elements.size == 1 && value.elements[0].tag == value.tag &&
        value.elements[0].interval == value.interval) then
      return value.elements[0]
    end
    value
  end

  attr_reader :elements, :tag, :interval, :text

  def initialize(syntax_node)
    @tag = syntax_node.lg_node
    @elements = QueryNode.resolve_elements(syntax_node.elements)
    @text = syntax_node.text_value.strip
    @interval = syntax_node.interval
  end

  def to_s
    "#{@tag} (#{@text})"
  end
end

module ListgameQuery
  def self.define_classes(class_names)
    class_names.each do |class_name|
      class_object = Class.new(Treetop::Runtime::SyntaxNode)
      class_object = self.const_set(class_name, class_object)

      class_object.class_eval do
        define_method(:lg_node) {
          class_name.downcase.to_sym
        }
      end
    end
  end

  def self.define_modules(module_names)
    module_names.each do |module_name|
      lg_node_sym = module_name.downcase.to_sym
      module_object = Module.new do
        define_method(:lg_node) do
          lg_node_sym
        end
      end
      self.const_set(module_name, module_object)
    end
  end

  CLASSES = %w/QueryTree QueryMode HavingClause UnquotedValue
               QueryRatioTail QueryBody QueryOr NickDeref
               Negation QueryKeywordExpr QueryKeyword Subquery
               SubqueryJoin QueryAlias OrderingSign QueryField
               OrderedField OrderedSpecialField FieldGrouping
               SubqueryMatch SloppyValue TypedFloat TypedInteger
               AggregateFunc QueryPart QueryFlagName QueryFlagExtra
               QueryIdentifier Sign SingleQuotedString DoubleQuotedString
               QueryFunctionTerm ExistSubquery/

  MODULES = %w/ResultIndex QueryClause HavingClauseKey
               HavingClauseQualifier SloppyExpr QueryOp AggregateField
               OrderedAggregateField FieldExtract QueryANDTerms
               QueryFlagBody SpecialField SortOperator QueryORExpr
               QueryOrdering SubqueryCondition Nick KeyOpVal
               NickSelector QueryCalcExpr QueryTerm TypedValue/
  self.define_classes(CLASSES)
  self.define_modules(MODULES)
end
