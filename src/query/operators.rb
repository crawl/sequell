module Query
  Operator.define(:and, argtype: '!', result: '!')
  Operator.define(:or, argtype: '!', result: '!')
  Operator.define(:not, argtype: '!', result: '!')
end
