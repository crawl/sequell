require 'query/keyword_matcher'

module Query
  KeywordMatcher.matcher(:god) {
    god_name = GODS.god_resolve_name(arg)
    return expr.parse('god', god_name) if god_name
  }

  KeywordMatcher.matcher(:ktyp) {
    ktyp_matches = SQL_CONFIG['prefix-field-fixups']['ktyp']
    match = ktyp_matches.keys.find { |ktyp| arg =~ /^#{ktyp}\w*$/i }
    return expr.parse('ktyp', ktyp_matches[match]) if match
  }

  KeywordMatcher.matcher(:version) {
    if arg =~ /^\d+[.]\d+([.]\d+)*(?:-\w+\d*)?$/
      return arg =~ /^\d+[.]\d+(?:$|-)/ ? 'cv' : 'v'
    end
  }

  KeywordMatcher.matcher(:source) {
    SOURCES.index(arg.downcase) && 'src'
  }

  KeywordMatcher.matcher(:boolean) {
    if value_field.boolean?
      return expr.parse(value.downcase, 'y')
    end
    if value_field.text?
      return expr.parse(value.downcase, '', expr.op.negate)
    end
  }
end
