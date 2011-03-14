class QueryContextFixups
  context :any do
  end

  MILESTONE_TYPES = HenzellConfig::CFG['milestone-types']

  BRANCHES = QueryConfig::CFG['branches'].map { |b| b.sub(':', '') }
  BRANCHES_WITH_DEPTHS = \
      (QueryConfig::CFG['branches'].find_all { |b| b =~ /:/ }.
                                    map { |b| b.sub(':', '') })

  BRANCH_KEYWORD_REGEXP = %r/^#{BRANCHES.join('|')}$/i
  BRANCH_DEPTH_REGEXP = %r/^(?:#{BRANCHES_WITH_DEPTHS.join('|')}):\d+$/i

  context :any do
    # Match simple branches or branches with depths as keywords
    keyword_match do |keyword|
      if keyword =~ BRANCH_KEYWORD_REGEXP || keyword =~ BRANCH_DEPTH_REGEXP
        SQLExpr.field_op_val('place', '=', keyword)
      end
    end
  end

  context 'lm' do
    # Given a query such as `!lm * abyss.enter`, translate the keyword
    # `abyss.enter` into `type=abyss.enter`
    keyword_match do |keyword|
      if MILESTONE_TYPES.include?(keyword.downcase)
        SQLExpr.field_op_val('type', '=', keyword)
      end
    end
  end
end
