require 'query/query_struct'
require 'query/query_keyword_parser'
require 'sql/version_number'
require 'sql/field_predicate'

module Query
  class QueryExprParser
    # Parses a single word of a listgame-style query, either as a keyword
    # parameter, or a field-op-value.
    def self.parse(arg)
      self.new(arg).parse
    end

    def initialize(arg)
      @rawarg = arg.dup
      @arg = arg.dup
    end

    def body
      @body ||= QueryStruct.new
    end

    def operator_missing?
      @arg !~ ARGSPLITTER
    end

    def field_pred(val, op, field, expr)
      Sql::FieldPredicate.predicate(val, op, field, expr)
    end

    def parse
      return QueryKeywordParser.parse(@arg) if operator_missing?

      @arg =~ ARGSPLITTER
      key, op, val = fixup_selector($1, $2, $3)
      key.downcase!
      val.downcase!
      val.tr! '_', ' '

      sort = (key == 'max' || key == 'min')

      selector = sort ? val.downcase : key
      selector = COLUMN_ALIASES[selector] || selector
      unless QueryContext.context.field?(selector)
        raise "Unknown selector: #{selector}"
      end

      raise "Bad sort: #{arg}" if sort && op != '='

      if sort
        order = key == 'max'? ' DESC' : ''
        body.sort("ORDER BY #{QueryContext.context.dbfield(selector)}#{order}")
      else
        sqlop = OPERATORS[op]
        field = selector.downcase
        if QueryContext.context.field_type(selector) == 'I'
          if ['=~','!~','~~', '!~~'].index(op)
            raise "Can't use #{op} on numeric field #{selector} in #{rawarg}"
          end
          val = val.to_i
        end
        body.append(query_field(selector, field, op, sqlop, val))
      end

      self.body
    end

    def query_field(selector, field, op, sqlop, val)
      selfield = selector
      if selector =~ /^\w+:(.*)/
        selfield = $1
      end

      if 'name' == selfield && val[0, 1] == '@' and [ '=', '!=' ].index(op)
        return NickExpr.expr(val[1..-1], op == '!=')
      end

      if ['v', 'cv'].index(selfield)
        if (['<', '<=', '>', '>='].index(op) &&
            val =~ /^\d+\.\d+(?:\.\d+)*(?:-[a-z]+[0-9]*)?$/)
          return field_pred(Sql::VersionNumber.version_numberize(val), op,
            selector.sub(/v$/i, 'vnum'),
            field.sub(/v$/i, 'vnum'))
        end
      end

      if ['killer', 'ckiller', 'ikiller'].index(selfield)
        if [ '=', '!=' ].index(op) and val !~ /^an? /i then
          if val.downcase == 'uniq' and ['killer', 'ikiller'].index(selfield)
            # Handle check for uniques.
            uniq = op == '='
            clause = QueryStruct.new(uniq ? 'AND' : 'OR')

            # killer field should not be empty.
            clause.append(field_pred('', OPERATORS[uniq ? '!=' : '='], selector, field))
            # killer field should not start with "a " or "an " for uniques
            clause.append(field_pred("^an? |^the ", OPERATORS[uniq ? '!~~' : '~~'],
                selector, field))
            clause.append(field_pred("ghost", OPERATORS[uniq ? '!~' : '=~'],
              selector, field))
          else
            clause = QueryStruct.new(op == '=' ? 'OR' : 'AND')
            clause.append(field_pred(val, sqlop, selector, field))
            clause.append(field_pred("a " + val, sqlop, selector, field))
            clause.append(field_pred("an " + val, sqlop, selector, field))
          end
          return clause
        end
      end

      if QueryContext.context.noun_verb[selfield]
        clause = QueryStruct.new
        key = QueryContext.context.noun_verb[selector]
        noun, verb = QueryContext.context.noun_verb_fields
        clause << field_pred(selector, '=', verb, verb)
        clause << field_pred(val, sqlop, noun, noun)
        return clause
      end

      if ((selfield == 'place' || selfield == 'oplace') and !val.index(':') and
          [ '=', '!=' ].index(op) and DEEP_BRANCH_SET.include?(val)) then
        val = val + ':*'
        op = op == '=' ? '=~' : '!~'
        sqlop = OPERATORS[op]
      end

      if selfield == 'race' || selfield == 'crace'
        if val.downcase == 'dr' && (op == '=' || op == '!=')
          sqlop = op == '=' ? OPERATORS['=~'] : OPERATORS['!~']
          val = "%#{val}"
        else
          val = RACE_EXPANSIONS[val.downcase] || val
        end
      end
      if selfield == 'cls'
        val = CLASS_EXPANSIONS[val.downcase] || val
      end

      if (selfield == 'place' and ['=', '!=', '=~', '!~'].index(op)) then
        place_fixups = CFG['place-fixups']
        for place_fixup_match in place_fixups.keys do
          regex = %r/#{place_fixup_match}/i
          if val =~ regex then
            replacement = place_fixups[place_fixup_match]
            replacement = [replacement] unless replacement.is_a?(Array)
            values = replacement.map { |r|
              val.sub(regex, r.sub(%r/\$(\d)/, '\\\1'))
            }
            inclusive = op.index('=') == 0
            clause = [inclusive ? 'OR' : 'AND']
            for value in values do
              clause << field_pred(value, sqlop, selector, field)
            end
            return clause
          end
        end
      end

      if selfield == 'when'
        tourney = tourney_info(val, GameContext.game)

        if [ '=', '!=' ].index(op)
          cv = tourney.version

          in_tourney = op == '='
          clause = QueryStruct.new(in_tourney ? 'AND' : 'OR')
          lop = in_tourney ? '>' : '<'
          rop = in_tourney ? '<' : '>'
          eqop = in_tourney ? '=' : '!='

          tstart = tourney.tstart
          tend   = tourney.tend

          end_time_field = QueryContext.context.raw_end_time_field
          clause << query_field('rstart', 'rstart', lop, lop, tstart)
          clause << query_field(end_time_field, end_time_field, rop, rop, tend)

          version_clause = [in_tourney ? 'OR' : 'AND']
          version_clause += cv.map { |cv_i|
            query_field('cv', 'cv', eqop, eqop, cv_i)
          }
          clause << version_clause
          if tourney.tmap
            clause << query_field('map', 'map', eqop, eqop, tourney.tmap)
          end
          return clause
        else
          raise "Bad selector #{selector} (#{selector}=t for tourney games)"
        end
      end

      field_pred(val, sqlop, selector, field)
    end

    def fixup_selector(key, op, val)
      # Check for regex operators in an equality check and map it to a
      # regex check instead.
      if (op == '=' || op == '!=') && val =~ /[()|?]/ then
        op = op == '=' ? '~~' : '!~~'
      end

      cval = val.downcase.strip
      rkey = COLUMN_ALIASES[key.downcase] || key.downcase
      eqop = ['=', '!='].index(op)
      if ['kaux', 'ckaux', 'killer', 'ktyp'].index(rkey) && eqop then
        if ['poison', 'poisoning'].index(cval)
          key, val = %w/ktyp pois/
        end
        if cval =~ /drown/
          key, val = %w/ktyp water/
        end
      end

      if rkey == 'ktyp' && eqop
        val = 'winning' if cval =~ /^win/ || cval =~ /^won/
        val = 'leaving' if cval =~ /^leav/ || cval == 'left'
        val = 'quitting' if cval =~ /^quit/
      end

      [key, op, val]
    end
  end
end
