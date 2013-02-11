require 'query/query_struct'
require 'query/query_keyword_parser'
require 'sql/version_number'
require 'sql/field_predicate'
require 'sql/field_expr_parser'
require 'sql/value'

module Query
  class QueryExprParser
    include Grammar

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

      if raw_key =~ /[|]/
        return split_clause(:or_clause, raw_key.split(/\|/), op, val)
      end

      if raw_key =~ /&/
        return split_clause(:and_clause, raw_key.split(/&/), op, val)
      end

      key = Sql::FieldExprParser.expr(raw_key)
      op = Sql::Operator.new(op)
      selector = key.sort? ? Sql::FieldExprParser.expr(val) : key
      raise "Bad sort: #{@arg}" if key.sort? && !op.equal?

      unless context.field?(selector.field)
        raise "Unknown field: #{selector}"
      end

      val = Sql::Value.cleanse_input(val)
      if key.sort?
        order = key.max? ? 'DESC' : 'ASC'
        body.sort(Sort.new(selector, order))
      else
        body.append(query_field(selector, op, val))
      end

      self.body
    end

    def query_field(field, op, val)
      val = 'n' if field.boolean? && val.empty?

      # Is it of the form ktyp=drowning|lava? Turn it into an a=x or a=y clause
      if op.equality? && val =~ /^\(?[\w. ]+(?:\|[\w. ]+)+\)?$/
        val = val.gsub(/^\(|\)$/, '')
        values = val.split('|')
        operator = op.equal? ? 'OR' : 'AND'
        return QueryStruct.new(operator, *values.map { |v|
          query_field(field, op, v)
        })
      end

      # Check for regex operators in an equality check and map it to a
      # regex check instead.
      if op.equality? && val =~ /[()|?]/ then
        op = Sql::Operator.op(op.equal? ? '~~' : '!~~')
      end

      if field.integer?
        if op.textual?
          raise "Can't use #{op} on numeric field #{field} in #{@rawarg}"
        end
        if val !~ /^[+-]?(?:\d+[.]?|[.]\d+|\d+[.]\d+)$/
          raise "Bad expression: '#{@arg}': #{field} is numeric, but value '#{val}' is not."
        end
        val = val.to_i
      end

      if field === 'name' && val =~ /^[@:]/ and op.equality?
        return NickExpr.expr(val, op.not_equal?)
      end

      if field === ['v', 'cv'] && op.relational? &&
          Sql::VersionNumber.version_number?(val)
        return field_pred(Sql::VersionNumber.version_numberize(val),
                          op,
                          field.resolve(field.name + 'num'))
      end

      if field === 'god'
        val = GODS.god_resolve_name(val) || val
      end

      if (field === ['map', 'killermap'] && op.equality? &&
          val =~ /^[\w -]+$/)
        op = Sql::Operator.op(op.equal? ? '~~' : '!~~')
        val = "^#{Regexp.quote(val)}($|;)"
      end

      if field === ['kaux', 'ckaux', 'killer', 'ktyp'] && op.equality? then
        if ['poison', 'poisoning'].index(val)
          field = field.resolve('ktyp')
          val = 'pois'
        end
        if val =~ /drown/
          field = field.resolve('ktyp')
          val = 'water'
        end
      end

      if field === 'ktyp' && op.equality?
        val = 'winning' if val =~ /^w[io]n/
        val = 'leaving' if val =~ /^leav/ || val == 'left'
        val = 'quitting' if val =~ /^quit/
      end

      if field === 'verb' && op.equality?
        val = Crawl::MilestoneType.canonicalize(val)
      end

      if field === ['killer', 'ckiller', 'ikiller']
        if op.equality? && val !~ /^an? /i && !UNIQUES.include?(val) then
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

      if field.value_key?
        return QueryStruct.new('AND',
          field_pred(context.canonical_value_key(field.to_s), '=',
                     context.key_field),
          field_pred(val, op, context.value_field))
      end

      if (field === 'place' || field === 'oplace') and !val.index(':') and
          op.equality? and BRANCHES.deep?(val) then
        val += BRANCHES.deepish?(val) ? '*' : ':*'
        op = Sql::Operator.new(op.equal? ? '=~' : '!~')
      end

      if (field === 'place' || field === 'oplace') and val =~ /:\*?$/ and
          op.equality? and BRANCHES.deep?(val) then
        val = val + '*' unless val =~ /\*$/
        op = Sql::Operator.new(op.equal? ? '=~' : '!~')
      end

      if field === 'race' || field === 'crace'
        if val.downcase == 'dr' && op.equality?
          op = Sql::Operator.new(op.equal? ? '=~' : '!~')
          val = "*draconian"
        else
          val = RACE_EXPANSIONS[val.downcase] || val
        end
      end
      if field === 'cls'
        val = CLASS_EXPANSIONS[val.downcase] || val
      end

      if field === ['place', 'oplace'] && op.equality? then
        fixed_up_places = PLACE_FIXUPS.fixup(val)
        return QueryStruct.new(op.equal? ? 'OR' : 'AND',
          *fixed_up_places.map { |place|
            field_pred(place, op, field)
          })
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
          clause << query_field(Sql::FieldExprParser.expr('rstart'),
                                lop, tstart)
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

    def split_clause(clause, keys, op, val)
      QueryStruct.send(clause, false,
        *keys.map { |split_key|
          QueryExprParser.parse("#{split_key}#{op}#{val}")
        })
    end
  end
end
