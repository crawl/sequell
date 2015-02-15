require 'query/keyword_matcher'
require 'query/ast/expr'
require 'cmd/user_keyword'
require 'crawl/playable'

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
      crace = Sql::Field.field('crace')
      Query::AST::Expr.or(*Crawl::Playable.species.map { |sp|
          Query::AST::Expr.new(expr.op, crace, sp)
        })
    end
  }

  KeywordMatcher.matcher(:playable_class) {
    if arg =~ /^playable:(?:job|j|class|cls|c)$/i
      fclass = Sql::Field.field('class')
      Query::AST::Expr.or(
        *Crawl::Playable.jobs.map { |job|
          Query::AST::Expr.new(expr.op, fclass, job)
        })
    end
  }

  KeywordMatcher.matcher(:playable_char) {
    if arg =~ /^playable(?::(?:char|combo))?$/
      fchar = Sql::Field.field('char')
      Query::AST::Expr.or(
        *Crawl::Playable.combos.map { |combo|
          Query::AST::Expr.new(expr.op, fchar, combo.to_s)
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
        sp_expansions = RACE_EXPANSIONS[arg.downcase].join('|')
        job_expansions = CLASS_EXPANSIONS[arg.downcase].join('|')
        raise "#{arg} is ambiguous: may be species or class. Use #{arg}-- (#{sp_expansions}) or --#{arg} (#{job_expansions}) to disambiguate"
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
    expr.parse('place', BRANCHES.canonical_place(arg)) if BRANCHES.branch?(arg)
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

  KeywordMatcher.matcher(:full_cls) {
    require 'crawl/job'
    'cls' if Crawl::Job.job_exists?(arg)
  }

  KeywordMatcher.matcher(:full_sp) {
    require 'crawl/species'
    if Crawl::Species.species_exists?(arg) ||
        Crawl::Species.flavoured_species?(arg)
      'sp'
    end
  }

  KeywordMatcher.matcher(:user_keyword) {
    user_keyword = Cmd::UserKeyword.keyword(arg)
    if user_keyword
      ListgameParser.fragment(user_keyword.definition)
    end
  }
end
