class Treetop::Runtime::SyntaxNode
  def lg_node
    nil
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
      module_object = Module.new
      self.const_set(module_name, module_object)
      module_object.module_eval do
        define_method(:lg_node) {
          module_name.downcase.to_sym
        }
      end
    end
  end

  CLASSES = %w/QueryTree QueryMode HavingClause
                         UnquotedValue
                         TypedValue QueryRatioTail QueryBody
                         QueryOr
                         NickSelector NickDeref Nick
                         Negation QueryKeywordExpr QueryKeyword
                         Subquery
                         SubqueryCondition
                         SubqueryJoin
                         QueryAlias
                         QueryOrdering
                         OrderingKey
QueryField
                         OrderedField OrderedSpecialField SpecialField
  FieldGrouping SubqueryMatch SloppyValue SloppyExpr TypedFloat TypedInteger
                        /

  MODULES = %w/ResultIndex QueryClause HavingClauseKey QueryOp/
  self.define_classes(CLASSES)
  self.define_modules(MODULES)
end
