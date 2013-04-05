require 'query/operator'
require 'grammar/config'

module Query
  ::Grammar::Config.operators.each { |op|
    Operator.define(op['op'].to_sym, op['negated'], op['sql_operator'], op)
  }
end
