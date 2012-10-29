require 'query/query_struct'
require 'query/query_keyword_parser'
require 'sql/version_number'
require 'sql/field_predicate'
require 'sql/field'
require 'sql/value'

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

    def field_pred(val, op, field)
      Sql::FieldPredicate.predicate(val, op, field)
    end

    def context
      @context ||= Sql::QueryContext.context
    end

    def parse
      return QueryKeywordParser.parse(@arg) if operator_missing?

      @arg =~ ARGSPLITTER
      raw_key, op, val = $1, $2, $3

      key = Sql::Field.new(raw_key)
      op = Sql::Operator.new(op)
      key, op, val = fixup_selector(key, op, val)

      val = Sql::Value.cleanse_input(val)

      selector = key.sort? ? Sql::Field.new(val) : key
      unless context.field?(selector)
        raise "Unknown selector: #{selector}"
      end

      raise "Bad sort: #{@arg}" if key.sort? && !op.equal?

      if key.sort?
        order = key.max? ? 'DESC' : 'ASC'
        body.sort(Sort.new(selector, order))
      else
        if context.integer?(selector)
          if op.textual?
            raise "Can't use #{op} on numeric field #{selector} in #{rawarg}"
          end
          val = val.to_i
        end
        body.append(query_field(selector, op, val))
      end

      self.body
    end

    def query_field(field, op, val)
      if field === 'name' && val[0, 1] == '@' and op.equality?
        return NickExpr.expr(val[1..-1], op.not_equal?)
      end

      if field === ['v', 'cv'] && op.relational? &&
          Sql::VersionNumber.version_number?(val)
        return field_pred(Sql::VersionNumber.version_numberize(val),
                          op,
                          field.resolve(field.name + 'num'))
      end

      if field === ['killer', 'ckiller', 'ikiller']
        if op.equality? and val !~ /^an? /i then
          if val.downcase == 'uniq' and field === ['killer', 'ikiller']
            # Handle check for uniques.
            uniq = op.equal?
            clause = QueryStruct.new(uniq ? 'AND' : 'OR')

            # killer field should not be empty.
            clause.append(field_pred('', op.negate, field))
            # killer field should not start with "a " or "an " for uniques
            clause.append(field_pred("^an? |^the ",
                                     Sql::Operator.new(uniq ? '!~~' : '~~'),
                                     field))
            clause.append(field_pred("ghost",
                                     Sql::Operator.new(uniq ? '!~' : '=~'),
                                     field))
            clause.append(field_pred("illusion",
                                     Sql::Operator.new(uniq ? '!~' : '=~'),
                                     field))
          else
            clause = QueryStruct.new(op.equal? ? 'OR' : 'AND')
            clause.append(field_pred(val, op, field))
            clause.append(field_pred("a " + val, op, field))
            clause.append(field_pred("an " + val, op, field))
          end
          return clause
        end
      end

      if context.value_key?(field)
        return QueryStruct.new(
          op.equal? ? 'AND' : 'OR',
          field_pred(field.to_s, op, context.key_field),
          field_pred(val, op, context.value_field))
      end

      if (field === 'place' || field === 'oplace') and !val.index(':') and
          op.equality? and BRANCHES.deep?(val) then
        val += ':*'
        op = Sql::Operator.new(op.equal? ? '=~' : '!~')
      end

      if field === 'race' || field === 'crace'
        if val.downcase == 'dr' && op.equality?
          op = Sql::Operator.new(op.equal? ? '=~' : '!~')
          val = "%draconian"
        else
          val = RACE_EXPANSIONS[val.downcase] || val
        end
      end
      if field === 'cls'
        val = CLASS_EXPANSIONS[val.downcase] || val
      end

      if field === ['place', 'oplace'] && op === ['=', '!=', '=~', '!~'] then
        place_fixups = CFG['place-fixups']
        for place_fixup_match in place_fixups.keys do
          regex = %r/#{place_fixup_match}/i
          if val =~ regex then
            replacement = place_fixups[place_fixup_match]
            replacement = [replacement] unless replacement.is_a?(Array)
            values = replacement.map { |r|
              val.sub(regex, r.sub(%r/\$(\d)/, '\\\1'))
            }
            inclusive = op.to_s.index('=') == 0
            clause = QueryStruct.new(inclusive ? 'OR' : 'AND')
            for value in values do
              clause << field_pred(value, op, field)
            end
            return clause
          end
        end
      end

      if field === 'when'
        tourney = tourney_info(val, GameContext.game)

        if op.equality?
          cv = tourney.version

          in_tourney = op.equal?
          clause = QueryStruct.new(in_tourney ? 'AND' : 'OR')
          lop = Sql::Operator.new(in_tourney ? '>' : '<')
          rop = Sql::Operator.new(in_tourney ? '<' : '>')
          eqop = Sql::Operator.new(in_tourney ? '=' : '!=')

          tstart = tourney.tstart
          tend   = tourney.tend

          time_field = context.raw_time_field
          clause << query_field(Sql::Field.new('rstart'), lop, tstart)
          clause << query_field(time_field, rop, tend)

          version_clause = QueryStruct.new(in_tourney ? 'OR' : 'AND')
          version_clause.append_all(cv.map { |cv_i|
            query_field(Sql::Field.new('cv'), eqop, cv_i)
          })
          clause << version_clause
          if tourney.tmap
            clause << query_field(Sql::Field.new('map'), eqop, tourney.tmap)
          end
          return clause
        else
          raise "Bad selector #{field} (#{field}=t for tourney games)"
        end
      end

      field_pred(val, op, field)
    end

    def fixup_selector(key, op, val)
      # Check for regex operators in an equality check and map it to a
      # regex check instead.
      if op.equality? && val =~ /[()|?]/ then
        op = Sql::Operator.op(op.equal? ? '~~' : '!~~')
      end

      cval = val.downcase.strip
      if key === ['kaux', 'ckaux', 'killer', 'ktyp'] && op.equality? then
        if ['poison', 'poisoning'].index(cval)
          key = key.resolve('ktyp')
          val = 'pois'
        end
        if cval =~ /drown/
          key = key.resolve('ktyp')
          val = 'water'
        end
      end

      if key === 'ktyp' && op.equality?
        val = 'winning' if cval =~ /^win/ || cval =~ /^won/
        val = 'leaving' if cval =~ /^leav/ || cval == 'left'
        val = 'quitting' if cval =~ /^quit/
      end

      if context.boolean?(key) && val.empty?
        val = 'n'
      end

      [key, op, val]
    end
  end
end
