require 'query/keyword_matcher'
require 'cmd/user_keyword'

module Query
  # These matches are applied in sequence, order is significant.

  KeywordMatcher.matcher(:nick) {
    'name' if arg =~ /^[@:]/
  }

  KeywordMatcher.matcher(:char_abbrev) {
    'char' if is_charabbrev?(arg)
  }

  KeywordMatcher.matcher(:playable_species) {
    if arg =~ /^playable:(?:sp|race|s|r)$/i
      require 'crawl/species'
      QueryStruct.or_clause(!expr.op.equal?,
        *Crawl::Species.available_species.map { |sp|
          Sql::FieldPredicate.predicate(sp.name, expr.op, 'crace')
        })
    end
  }

  KeywordMatcher.matcher(:playable_class) {
    if arg =~ /^playable:(?:job|j|class|cls|c)$/i
      require 'crawl/job'
      QueryStruct.or_clause(!expr.op.equal?,
        *Crawl::Job.available_jobs.map { |job|
          Sql::FieldPredicate.predicate(job.name, expr.op, 'class')
        })
    end
  }

  KeywordMatcher.matcher(:playable_char) {
    if arg =~ /^playable(?::(?:char|combo))?$/
      require 'crawl/combo'
      QueryStruct.or_clause(!expr.op.equal?,
        *Crawl::Combo.available_combos.map { |combo|
          Sql::FieldPredicate.predicate(combo.to_s, expr.op, 'char')
        })
    end
  }

  KeywordMatcher.matcher(:playable_goodchar) {
    if arg =~ /^playable:good(?:char|combo)?$/
      require 'crawl/combo'
      QueryStruct.or_clause(!expr.op.equal?,
        *Crawl::Combo.good_combos.map { |combo|
          Sql::FieldPredicate.predicate(combo.to_s, expr.op, 'char')
        })
    end
  }

  KeywordMatcher.matcher(:playable_badchar) {
    if arg =~ /^playable:bad(?:char|combo)?$/
      require 'crawl/combo'
      QueryStruct.or_clause(!expr.op.equal?,
        *Crawl::Combo.bad_combos.map { |combo|
          Sql::FieldPredicate.predicate(combo.to_s, expr.op, 'char')
        })
    end
  }

  KeywordMatcher.matcher(:playable_class) {
    if arg == 'sp_playable'
      require 'crawl/species'
      QueryStruct.or_clause(expr.op.equal?,
        *Crawl::Species.available_species.map { |sp|
          Sql::FieldPredicate.predicate(sp.name, expr.op, 'sp')
        })
    end
  }

  KeywordMatcher.matcher(:anchored_race) {
    if arg =~ /^([a-z]{2})[_-]{2}$/i then
      sp = $1
      return expr.parse('crace', sp) if is_race?(sp)
    end
  }

  KeywordMatcher.matcher(:anchored_class) {
    if arg =~ /^[_-]{2}([a-z]{2})$/i then
      cls = $1
      return expr.parse('cls', cls) if is_class?(cls)
    end
  }

  KeywordMatcher.matcher(:race_or_class) {
    if arg =~ /^[a-z]{2}$/i then
      cls = is_class?(arg)
      sp = is_race?(arg)
      return expr.parse('cls', arg) if cls && !sp
      return expr.parse('crace', arg) if sp && !cls
      if cls && sp
        raise "#{arg} is ambiguous: may be species or class. Use #{arg}-- (#{RACE_EXPANSIONS[arg.downcase]}) or --#{arg} (#{CLASS_EXPANSIONS[arg.downcase]}) to disambiguate"
      end
    end
  }

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

  KeywordMatcher.matcher(:branch) {
    'place' if BRANCHES.branch?(arg)
  }

  KeywordMatcher.matcher(:tourney) {
    'when' if tourney_keyword?(arg)
  }

  KeywordMatcher.matcher(:rune_type) {
    'verb' if context.value_key?(arg)
  }

  KeywordMatcher.matcher(:boolean) {
    return unless value_field.known?
    if value_field.boolean?
      return expr.parse(value.downcase, 'y')
    end
    if value_field.text?
      return expr.parse(value.downcase, '', expr.op.negate)
    end
  }

  KeywordMatcher.matcher(:game_type) {
    game = arg.downcase
    if SQL_CONFIG.games.index(game)
      GameContext.game = game
      return true
    end
  }

  KeywordMatcher.matcher(:user_keyword) {
    user_keyword = Cmd::UserKeyword.keyword(arg)
    if user_keyword
      qs = Query::QueryString.new(user_keyword.definition)
      qs.normalize!
      return Query::QueryParamParser.parse(qs).without_sorts
    end
  }
end
