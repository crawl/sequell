require 'query/nick_expr'
require 'formatter/duration'

module Query
  class QueryNodeTranslator
    def self.translate(node, parent)
      self.new(node, parent).translate
    end

    attr_reader :node, :parent

    def initialize(node, parent)
      @node = node
      @parent = parent
    end

    def value
      node.value
    end

    def field
      node.field
    end

    def op
      node.operator
    end

    def equality?
      node.equality?
    end

    def context
      ::Sql::QueryContext.context
    end

    def translate
      return translate_simple_predicate(node) if node.field_value_predicate?
      return translate_funcall(node) if node.kind == :funcall
      node
    end

    def reexpand(node)
      ::Query::AST::ASTTranslator.apply(node)
    end

    def expand_field_value!
      transformed_value = SQL_CONFIG.transform_value(value.to_s, field)
      oper = op
      if transformed_value.to_s.index('~') == 0
        transformed_value = transformed_value[1..-1]
        op = Sql::Operator.op(op.equal? ? '=~' : '!~')
      end
      node.operator = oper
      node.value = transformed_value
    end

    def translate_funcall(node)
      # Count foreign key ids instead of field values for count(distinct)
      if node.fn.count? && node.arguments[0].kind == :field
        f = node.arguments[0]
        if f.reference? && !f.case_sensitive?
          f.reference_id_only = true
        end
      end
      node
    end

    def translate_simple_predicate(node)
      if equality? && value =~ /^\(?[^| ]+(?:\|[^| ]+)+\)?$/
        values = value.gsub(/^\(|\)$/, '').split('|')
        operator = (op.equal? ? :or : :and)
        return reexpand(
          AST::Expr.new(operator, *values.map { |val|
              AST::Expr.new(self.op, self.field, val)
            }))
      end

      if equality? && field === 'name'
        return nil if value =~ /^[@:]*[*]$/
        if value =~ /^[@:.]/ || node.is_a?(::Query::NickExpr)
          return ::Query::NickExpr.expr(value, !op.equal?)
        end
      end

      if field.multivalue? && op.equality? && value.index(',')
        values = value.split(',').map { |s| s.strip }
        operator = (op.equal? ? :and : :or)
        return reexpand(AST::Expr.new(operator, *values.map { |v|
              AST::Expr.new(op, field, v)
            }))
      end

      expand_field_value! if equality?

      if field === 'src' && equality?
        node.value = SOURCES.canonical_source(value)
      end

      if field === ['v', 'cv', 'vlong'] && op.relational? &&
          Sql::VersionNumber.version_number?(value)
        return reexpand(AST::Expr.new(op, field.resolve(field.name + 'num'),
                                 Sql::VersionNumber.version_numberize(value)))
      end

      if field === 'god'
        node.value = GODS.god_resolve_name(value) || value
      end

      if (field === ['map', 'killermap'] && equality? &&
          value =~ /^[\w -]+$/)
        node.operator = op.equal? ? '~~' : '!~~'
        node.value = "^#{Regexp.quote(value)}($|;)"
      end

      if field === 'verb' && equality?
        node.value = Crawl::MilestoneType.canonicalize(value) || value.to_s.strip.downcase
      end

      if field.multivalue? && equality? && !value.empty?
        node.operator = op.equal? ? '~~' : '!~~'
        node.value = "(?:^|,)" + Regexp.quote(value) + '\y'
      end

      if field === ['killer', 'ckiller', 'ikiller'] && !value.empty? &&
          !node.flags[:killer_expanded]
        if equality? && value !~ /^an? /i && !UNIQUES.include?(value) then
          if value.downcase == 'uniq' and field === ['killer', 'ikiller', 'ckiller']
            # Handle check for uniques.
            uniq = op.equal?
            operator = (uniq ? :and : :or)
            return reexpand(
              AST::Expr.new(operator,
                AST::Expr.new(op.negate, field, ''),
                AST::Expr.new(operator,
                  *Crawl::Config['orcs'].map { |orc|
                    AST::Expr.new(uniq ? '!=' : '=', field, orc)
                  }),
                AST::Expr.new(uniq ? '~~' : '!~~', field, "(?c)^[A-Z]"),
                AST::Expr.new(uniq ? '!~~' : '~~', field, "^an? |^the "),
                AST::Expr.new(uniq ? '!~' : '~~', field, "ghost"),
                AST::Expr.new(uniq ? '!~' : '~~', field, "pandemonium lord"),
                AST::Expr.new(uniq ? '!~' : '~~', field, "illusion")).recursive_flag!(:killer_expanded))
          else
            return AST::Expr.new(op.equal? ? :or : :and,
              AST::Expr.new(op, field, value),
              AST::Expr.new(op, field, "a " + value),
              AST::Expr.new(op, field, "an " + value)).recursive_flag!(:killer_expanded)
          end
        end
      end

      if field.value_key?
        return reexpand(
          AST::Expr.and(
            AST::Expr.field_predicate('=', context.key_field,
              context.canonical_value_key(field.to_s)),
            AST::Expr.field_predicate(op, context.value_field, value)))
      end

      if (field === 'place' || field === 'oplace') and !value.index(':') and
          equality? and BRANCHES.deep?(value) then
        node.value += BRANCHES.deepish?(value) ? '*' : ':*'
        node.operator = op.equal? ? '=~' : '!~'
      end

      if (field === 'place' || field === 'oplace') and value =~ /:\*?$/ and
          op.equality? and BRANCHES.deep?(value) then
        node.value += '*' unless value =~ /\*$/
        node.operator = op.equal? ? '=~' : '!~'
      end

      if (field === 'race' || field === 'crace') && op.equality?
        if value.downcase == 'dr'
          node.operator = op.equal? ? '=~' : '!~'
          node.value = "*draconian"
        else
          return AST::Expr.field_predicate(op, field,
            RACE_EXPANSIONS[value.downcase] || value)
        end
      end

      if field === 'dur' && (value =~ /\d+:\d+$/ || value =~ /\d+d/ || value =~ /\d+y/)
        node.value = Formatter::Duration.parse(value.to_s)
      end

      if field === 'cls' && op.equality?
        return AST::Expr.field_predicate(op, field,
          CLASS_EXPANSIONS[value.downcase] || value)
      end

      if field === ['place', 'oplace'] && op.equality? then
        fixed_up_places = PLACE_FIXUPS.fixup(value)
        return AST::Expr.new(op.equal? ? :or : :and,
          *fixed_up_places.map { |place|
            AST::Expr.field_predicate(op, field, place)
          })
      end

      if field === 'when'
        tourney = tourney_info(value, GameContext.game)

        if op.equality?
          cv = tourney.version

          in_tourney = op.equal?

          clause_op = (in_tourney ? :and : :or)
          lop = in_tourney ? '>' : '<'
          rop = in_tourney ? '<' : '>'
          eqop = in_tourney ? '=' : '!='

          tstart = tourney.tstart
          tend   = tourney.tend

          time_field = context.raw_time_field

          return AST::Expr.new(clause_op,
            AST::Expr.field_predicate(lop, 'rstart', tstart),
            AST::Expr.field_predicate(rop, time_field, tend),
            AST::Expr.new(in_tourney ? :or : :and,
              *cv.map { |cv_i|
                AST::Expr.field_predicate(eqop, 'cv', cv_i)
              }),
            (tourney.tmap &&
              AST::Expr.field_predicate(eqop, 'map', tourney.tmap)))
        else
          raise "Bad selector #{field} (#{field}=t for tourney games)"
        end
      end

      node
    end
  end
end
