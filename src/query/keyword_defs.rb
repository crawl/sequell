require 'query/keyword_matcher'
require 'query/ast/expr'
require 'cmd/user_keyword'

module Query
  # These matches are applied in sequence, order is significant.

  KeywordMatcher.matcher(:nick) {
    'name' if arg =~ /^[@:]/ || arg == '.' || arg == '*'
  }

  KeywordMatcher.matcher(:char_abbrev) {
    'char' if is_charabbrev?(arg)
  }

  KeywordMatcher.matcher(:playable_species) {
    if arg =~ /^playable:(?:sp|race|s|r)$/i
      require 'crawl/species'
      crace = Sql::Field.field('crace')
      Query::AST::Expr.or(*Crawl::Species.available_species.map { |sp|
          Query::AST::Expr.new(expr.op, crace, sp.name)
        })
    end
  }

  KeywordMatcher.matcher(:playable_class) {
    if arg =~ /^playable:(?:job|j|class|cls|c)$/i
      require 'crawl/job'
      fclass = Sql::Field.field('class')
      Query::AST::Expr.or(
        *Crawl::Job.available_jobs.map { |job|
          Query::AST::Expr.new(expr.op, fclass, job.name)
        })
    end
  }

  KeywordMatcher.matcher(:playable_char) {
    if arg =~ /^playable(?::(?:char|combo))?$/
      require 'crawl/combo'
      fchar = Sql::Field.field('char')
      Query::AST::Expr.or(
        *Crawl::Combo.available_combos.map { |combo|
          Query::AST::Expr.new(expr.op, fchar, combo.to_s)
        })
    end
  }

  KeywordMatcher.matcher(:playable_goodchar) {
    if arg =~ /^playable:good(?:char|combo)?$/
      require 'crawl/combo'
      fchar = Sql::Field.field('char')
      Query::AST::Expr.or(
        *Crawl::Combo.good_combos.map { |combo|
          Query::AST::Expr.new(expr.op, fchar, combo.to_s)
        })
    end
  }

  KeywordMatcher.matcher(:playable_badchar) {
    if arg =~ /^playable:bad(?:char|combo)?$/
      require 'crawl/combo'
      fchar = Sql::Field.field('char')
      Query::AST::Expr.or(
        *Crawl::Combo.bad_combos.map { |combo|
          Query::AST::Expr.new(expr.op, fchar, combo.to_s)
        })
    end
  }

  KeywordMatcher.matcher(:playable_class) {
    if arg == 'sp_playable'
      require 'crawl/species'
      fsp = Sql::Field.field('sp')
      Query::AST::Expr.or(
        *Crawl::Species.available_species.map { |sp|
          Query::AST::Expr.new(expr.op, fsp, sp.name)
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

  KeywordMatcher.matcher(:prefixed_field_fixups) {
    SQL_CONFIG['prefix-field-fixups'].each { |field, map|
      match = map.keys.find { |fval|
        long_form = map[fval].downcase
        lcarg.index(fval) == 0 && (fval == lcarg || long_form.index(lcarg) == 0)
      }
      return expr.parse(field, map[match]) if match
    }
    nil
  }

  KeywordMatcher.matcher(:version) {
    if arg =~ /^\d+[.]\d+([.]\d+)*(?:-\w+\d*)?$/
      return arg =~ /^\d+[.]\d+(?:$|-)/ ? 'cv' : 'v'
    end
  }

  KeywordMatcher.matcher(:source) {
    expr.parse('src', SOURCES.canonical_source(arg)) if SOURCES.source?(arg)
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
      Query::AST::Expr.new(:'=', Sql::Field.field('game'), game)
    end
  }

  KeywordMatcher.matcher(:user_keyword) {
    user_keyword = Cmd::UserKeyword.keyword(arg)
    if user_keyword
      ListgameParser.fragment(user_keyword.definition)
    end
  }
end
