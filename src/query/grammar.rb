module Query
  module Grammar
    OPERATORS = {
      '==' => '=',
      '!==' => '!=',
      '=' => '=',
      '!=' => '!=',
      '<' => '<',
      '>' => '>',
      '<=' => '<=',
      '>=' => '>=',
      '=~' => 'ILIKE',
      '!~' => 'NOT ILIKE',
      '~~' => '~*',
      '!~~' => '!~*'
    }

    OPERATOR_NEGATION = {
      '=='  => '!==',
      '='   => '!=',
      '<'   => '>=',
      '>'   => '<=',
      '=~'  => '!~',
      '~~'  => '!~~'
    }
    OPERATOR_NEGATION.merge!(OPERATOR_NEGATION.invert)

    SORTEDOPS = OPERATORS.keys.sort { |a,b| b.length <=> a.length }
    OPMATCH = Regexp.new(SORTEDOPS.map { |o| Regexp.quote(o) }.join('|'))

    FIELD = Regexp.new('[a-z.:_]+', Regexp::IGNORECASE)
    FUNCTION = Regexp.new('[a-z]\w+', Regexp::IGNORECASE)
    FUNCTION_CALL = Regexp.new("#{FUNCTION}\\(#{FIELD}\\)", Regexp::IGNORECASE)
    ARGSPLITTER = Regexp.new("^-?(#{FUNCTION_CALL}|#{FIELD})\\s*(" +
                             SORTEDOPS.map { |o| Regexp.quote(o) }.join("|") +
                             ')\s*(.*)$', Regexp::IGNORECASE)


    FILTER_OPS = {
      '<'   => Proc.new { |a, b| a.to_f < b },
      '<='  => Proc.new { |a, b| a.to_f <= b },
      '>'   => Proc.new { |a, b| a.to_f > b },
      '>='  => Proc.new { |a, b| a.to_f >= b },
      '='   => Proc.new { |a, b| a.to_f == b },
      '!='  => Proc.new { |a, b| a.to_f != b }
    }

    FILTER_OPS_ORDERED = FILTER_OPS.keys.sort { |a,b| b.length <=> a.length }

    FILTER_PATTERN =
      Regexp.new('^((?:(?:den|num|%)[.])?\S+?)(' +
                 FILTER_OPS_ORDERED.map { |o| Regexp.quote(o) }.join('|') +
                 ')(\S+)$')

    OPEN_PAREN = '(('
    CLOSE_PAREN = '))'

    BOOLEAN_OR = '||'
    BOOLEAN_OR_Q = Regexp.quote(BOOLEAN_OR)
  end
end
