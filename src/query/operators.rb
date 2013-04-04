require 'query/operator'

module Query
  Operator.define(:and, :or, argtype: '!', result: '!')
  Operator.define(:or, :and, argtype: '!', result: '!')
  Operator.define(:not, :and, argtype: '!', result: '!', arity: 1)
  Operator.define(:'=', :'!=', argtype: '*', result: '!', arity: 2)
  Operator.define(:'!=', :'=', argtype: '*', result: '!', arity: 2)
  Operator.define(:'==', :'!==', argtype: '*', result: '!', arity: 2)
  Operator.define(:'!==', :'==', argtype: '*', result: '!', arity: 2)
  Operator.define(:'=~', :'!~', argtype: 'S', result: '!', arity: 2,
                  non_commutative: true)
  Operator.define(:'!~', :'~', argtype: 'S', result: '!', arity: 2,
                  non_commutative: true)
  Operator.define(:'~~', :'!~~', argtype: 'S', result: '!', arity: 2,
                  non_commutative: true)
  Operator.define(:'!~~', :'~~', argtype: 'S', result: '!', arity: 2,
                  non_commutative: true)
  Operator.define(:'<', :'>=', argtype: '*', result: '!', arity: 2,
                  non_commutative: true)
  Operator.define(:'<=', :'>', argtype: '*', result: '!', arity: 2,
                  non_commutative: true)
  Operator.define(:'>', :'<=', argtype: '*', result: '!', arity: 2,
                  non_commutative: true)
  Operator.define(:'>=', :'<', argtype: '*', result: '!', arity: 2,
                  non_commutative: true)
end
