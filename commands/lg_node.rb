class Treetop::Runtime::SyntaxNode
  attr_writer :elements
  attr_accessor :lg_node
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
               OrderedAggregateField FieldExtract JoinFields QueryANDTerms
               QueryFlagBody SpecialField SortOperator QueryORExpr
               QueryOrdering SubqueryCondition Nick KeyOpVal
               NickSelector QueryCalcExpr QueryTerm TypedValue/
  self.define_classes(CLASSES)
  self.define_modules(MODULES)
end
