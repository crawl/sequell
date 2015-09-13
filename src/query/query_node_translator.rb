require 'query/nick_expr'
require 'formatter/duration'
require 'query/ast/extra_list'
require 'query/ast/extra'

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

    def context
      @context ||= node.context
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

    def translate
      return translate_simple_predicate(node) if node.field_value_predicate?
      return translate_field_field_predicate(node) if node.field_field_predicate?
      return translate_funcall(node) if node.kind == :funcall
      return translate_ref_fields_to_ids(node) if case_insensitive_in_subquery?(node)
      node
    end

    private

    def reexpand(node)
      ::Query::AST::ASTTranslator.apply(node)
    end

    def case_insensitive_in_subquery?(node)
      node.operator && node.operator.in? && node.left.kind == :field &&
        node.left.reference? &&
        !node.left.type.case_sensitive? && node.right.kind == :subquery_expr
    end

    ##
    # Given a query of the form field=*$[ x=field ] where field is a
    # case-insensitive lookup field, convert it into the form
    # field_id=*$[ x=field_id ] to avoid a redundant join on the lookup
    # table in both outer and inner queries.
    #
    # This optimization is skipped if the field is case-sensitive, because in
    # that case, the subquery may return a *single* id for its field (say
    # "blue death"), but the outer query should match it even if the outer
    # query's field is for an alternative case (say "Blue Death").
    def translate_ref_fields_to_ids(node)
      subquery = node.right.query

      if subquery.grouped?
        # Multigroup subqueries are trouble, bail out:
        return node unless subquery.summarise.arity == 1

        # If the user specified an explicit select that doesn't match what we
        # wanted, bail out.
        if subquery.extra
          return node if subquery.extra.arity != 1
          return node if subquery.extra.first.kind != :field
          return node if subquery.extra.first != node.left
        end

        group = subquery.summarise.first
        if group.first.kind == :field && group.first == node.left
          subquery_force_select(subquery, node.left.name)
          group.first.reference_id_only = true
          node.left.reference_id_only = true
          subquery.extra.first.first.reference_id_only = true
          return node
        end
      end

      # If there's no x=foo, force one:
      subquery_force_select(subquery, node.left.name)

      extra_field = subquery.extra.first
      if extra_field.simple_field? && extra_field.expr == node.left &&
         !extra_field.type.case_sensitive?
        extra_field.expr.reference_id_only = true
        node.left.reference_id_only = true
      end
      node
    end

    def subquery_force_select(subquery, fieldname)
      return if subquery.extra
      extra_term = Query::AST::Extra.new(Sql::Field.field(fieldname))
      subquery.extra = Query::AST::ExtraList.new(extra_term)
      subquery.bind(subquery.extra)
    end

    def expand_field_value!
      transformed_value = SQL_CONFIG.transform_value(value.to_s, field)
      oper = self.op
      if transformed_value.to_s.index('~') == 0
        transformed_value = transformed_value[1..-1]
        oper = ::Query::Operator.op(oper.equal? ? '=~' : '!~')
      end
      node.operator = oper
      node.value = transformed_value
    end

    def translate_funcall(node)
      # Count foreign key ids instead of field values for count(distinct)
      if node.fn.count? && !node.arguments.empty? && node.arguments[0].kind == :field
        f = node.arguments[0]
        if f.reference? && !f.case_sensitive?
          f.reference_id_only = true
        end
      end
      node
    end

    def god_field?(field)
      field.name =~ /^god(?:$|[.])/i
    end

    ##
    # Translate RHS values into fields if they're expressed in the foo:bar
    # form, and unquoted.
    def translate_qualified_value_to_field(node)
      rhs = node.right
      if rhs.kind != :value
        raise("Expected #{rhs} to be a value in #{node}")
      end
      return if rhs.flag(:quoted_string)     # Don't mess with quoted strings.
      return unless rhs.value.is_a?(String)  # Don't bother with non-strings

      right = Sql::Field.field(rhs.value).bind_context(node.context)
      right_col = node.context.resolve_column(right, :internal_expr)

      if right_col && right.prefix
        node.right = right
        return node
      end
      nil
    end

    def translate_field_field_predicate(node)
      return node unless op && op.equality?

      if reference_id_comparison?(node) && !node.left.case_sensitive? && !node.right.case_sensitive?
        node.left.reference_id_only = true
        node.right.reference_id_only = true
      end
      node
    end

    ##
    # Returns true for comparisons such as killer=${ckiller}, which are both
    # reference fields in the same reference table.
    def reference_id_comparison?(node)
      left = node.left
      right = node.right
      left.reference? && right.reference? && left.column && right.column &&
        left.column.lookup_table == right.column.lookup_table
    end

    def translate_simple_predicate(node)
      translated_node = translate_qualified_value_to_field(node)
      return reexpand(translated_node) if translated_node

      if equality? && value =~ /^\(?[^| ]+(?:\|[^| ]+)+\)?$/
        values = value.gsub(/^\(|\)$/, '').split('|')
        operator = (op.equal? ? :or : :and)
        return reexpand(
          node.bind(AST::Expr.new(operator, *values.map { |val|
                                    AST::Expr.new(self.op, self.field, val)
                                  })))
      end

      if equality? && field === 'name'
        return nil if value =~ /^[@:]*[*]$/
        if value =~ /^[@:.]/ || node.is_a?(::Query::NickExpr)
          return node.bind(::Query::NickExpr.expr(value, !op.equal?))
        end
      end

      if field.multivalue? && op.equality? && value.index(',')
        values = value.split(',').map { |s| s.strip }
        operator = (op.equal? ? :and : :or)
        return reexpand(node.bind(
                         AST::Expr.new(operator, *values.map { |v|
                                         AST::Expr.new(op, field, v)
                                       })))
      end

      expand_field_value! if equality?

      if field === 'src' && equality?
        node.value = SOURCES.canonical_source(value)
      end

      if field.version_number? && op.relational? &&
          Sql::VersionNumber.version_number?(value)
        return reexpand(
          node.bind(
            AST::Expr.new(op, field.bind_ordered_column!,
                          Sql::VersionNumber.version_numberize(value))))
      end

      if god_field?(field)
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

      if field === ['killer', 'ckiller', 'ikiller', 'cikiller', 'banisher', 'cbanisher'] &&
          !value.empty? && !node.flags[:killer_expanded]
        if equality? && value !~ /^an? /i && !UNIQUES.include?(value) then
          if value.downcase == 'uniq' and field === ['killer', 'ikiller', 'ckiller']
            # Handle check for uniques.
            uniq = op.equal?
            operator = (uniq ? :and : :or)
            return reexpand(
                     node.bind(
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
                AST::Expr.new(uniq ? '!~' : '~~', field, "illusion"))).recursive_flag!(:killer_expanded))
          else
            return node.bind(AST::Expr.new(op.equal? ? :or : :and,
              AST::Expr.new(op, field, value),
              AST::Expr.new(op, field, "a " + value),
              AST::Expr.new(op, field, "an " + value))).recursive_flag!(:killer_expanded)
          end
        end
      end

      if field.value_key?
        return reexpand(
          field.bind(AST::Expr.and(
                      AST::Expr.field_predicate('=', context.key_field,
                                                context.canonical_value_key(field.to_s)),
                      AST::Expr.field_predicate(op, context.value_field, value))))
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
          return node.bind(AST::Expr.field_predicate(op, field,
            RACE_EXPANSIONS[value.downcase] || value))
        end
      end

      if field === 'dur' && (value =~ /\d+:\d+$/ || value =~ /\d+d/ || value =~ /\d+y/)
        node.value = Formatter::Duration.parse(value.to_s)
      end

      if field === 'cls' && op.equality?
        return node.bind(AST::Expr.field_predicate(op, field,
          CLASS_EXPANSIONS[value.downcase] || value))
      end

      if field === ['place', 'oplace'] && op.equality? then
        fixed_up_places = PLACE_FIXUPS.fixup(value)
        return node.bind(AST::Expr.new(op.equal? ? :or : :and,
          *fixed_up_places.map { |place|
            AST::Expr.field_predicate(op, field, place)
          }))
      end

      if field === 'when'
        if tourney_wildcard?(value)
          return reexpand(AST::Expr.new(op, field, tourney_all_keys().join('|')))
        end

        tourney = tourney_info(value, GameContext.game)

        if op.equality?
          cv = tourney.version

          in_tourney = op.equal?

          clause_op = (in_tourney ? :and : :or)
          lop = in_tourney ? '>=' : '<'
          rop = in_tourney ? '<' : '>='
          eqop = in_tourney ? '=' : '!='

          tstart = tourney.tstart
          tend   = tourney.tend

          time_field = context.time_field

          return node.bind(AST::Expr.new(clause_op,
            AST::Expr.field_predicate(lop, 'start', tstart.to_s),
            AST::Expr.field_predicate(rop, time_field, tend.to_s),
            AST::Expr.new(in_tourney ? :or : :and,
              *cv.map { |cv_i|
                AST::Expr.field_predicate(eqop, 'cv', cv_i)
              }),
            AST::Expr.field_predicate(eqop, 'explbr', ''),
            (tourney.tmap &&
              AST::Expr.field_predicate(eqop, 'map', tourney.tmap))))
        else
          raise "Bad selector #{field} (#{field}=t for tourney games)"
        end
      end

      node
    end
  end
end
